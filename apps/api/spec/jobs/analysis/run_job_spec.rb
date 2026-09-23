require "rails_helper"

RSpec.describe Analysis::RunJob do
  around do |example|
    original_model = ENV["GEMINI_MODEL"]
    ENV["GEMINI_MODEL"] = "gemini-test-model"
    example.run
    ENV["GEMINI_MODEL"] = original_model
  end

  def stub_gemini(data)
    stub_request(:post, /generativelanguage\.googleapis\.com/).to_return(
      status: 200,
      body: {
        candidates: [ { content: { parts: [ { text: data.to_json } ] } } ],
        usageMetadata: { promptTokenCount: 500, candidatesTokenCount: 120 }
      }.to_json,
      headers: { "Content-Type" => "application/json" }
    )
  end

  let(:valid_output) do
    { "summary" => "Vais bien", "coverage" => [], "orphan_features" => [], "gaps" => [], "risks" => [] }
  end

  def enqueue(team, trigger: "manual")
    Analysis::Enqueue.call(team: team, trigger: trigger)
  end

  # RF-AI-021: sin requested_by, resolve_api_key usa la clave del owner.
  def team_with_ai_key
    team = create(:team, :with_owner)
    team.memberships.first.user.update!(gemini_api_key: "test-key")
    team
  end

  it "crea un AiAnalysis succeeded con el resultado posvalidado" do
    team = team_with_ai_key
    stub_gemini(valid_output)
    analysis = enqueue(team)

    described_class.new.perform(analysis.id.to_s)

    analysis.reload
    expect(analysis.status).to eq("succeeded")
    expect(analysis.result["summary"]).to eq("Vais bien")
    expect(analysis.usage).to eq("input_tokens" => 500, "output_tokens" => 120)
    expect(analysis.prompt_version).to eq("coverage_v1")
  end

  it "en manual con requested_by, usa la clave de quien lo pidió y no la del owner" do
    team = create(:team, :with_owner)
    requester = create(:membership, team: team, role: "member")
    requester.user.update!(gemini_api_key: "requester-key")
    stub_gemini(valid_output)
    analysis = Analysis::Enqueue.call(team: team, trigger: "manual", requested_by: requester.user)

    described_class.new.perform(analysis.id.to_s)

    expect(a_request(:post, /generativelanguage\.googleapis\.com/).with(query: hash_including("key" => "requester-key")))
      .to have_been_requested
    expect(analysis.reload.status).to eq("succeeded")
  end

  it "no llama a la IA si el contexto no cambió desde el último análisis completado (skip)" do
    team = team_with_ai_key
    stub = stub_gemini(valid_output)

    described_class.new.perform(enqueue(team).id.to_s)
    second = enqueue(team)
    described_class.new.perform(second.id.to_s)

    expect(stub).to have_been_requested.once
    expect(second.reload.status).to eq("skipped")
    expect(second.skip_reason).to eq("no_changes")
  end

  it "marca skipped/no_api_key si nadie del equipo tiene una clave de Gemini configurada" do
    team = create(:team, :with_owner)
    analysis = enqueue(team)

    described_class.new.perform(analysis.id.to_s)

    expect(a_request(:post, /generativelanguage\.googleapis\.com/)).not_to have_been_made
    expect(analysis.reload.status).to eq("skipped")
    expect(analysis.skip_reason).to eq("no_api_key")
  end

  it "marca failed si la IA no devuelve un JSON que cumpla el schema, tras reintentar una vez" do
    team = team_with_ai_key
    stub = stub_gemini({ "summary" => "falta todo lo demás" })
    analysis = enqueue(team)

    described_class.new.perform(analysis.id.to_s)

    expect(stub).to have_been_requested.times(2)
    expect(analysis.reload.status).to eq("failed")
  end

  it "no ejecuta dos análisis a la vez para el mismo equipo (lock)" do
    team = team_with_ai_key
    analysis = enqueue(team)
    Analysis::Lock.acquire(team.id.to_s)

    described_class.new.perform(analysis.id.to_s)

    expect(analysis.reload.status).to eq("queued")
  end

  it "es idempotente: no vuelve a ejecutar un análisis que ya no está queued" do
    team = team_with_ai_key
    stub = stub_gemini(valid_output)
    analysis = enqueue(team)
    described_class.new.perform(analysis.id.to_s)

    described_class.new.perform(analysis.id.to_s)

    expect(stub).to have_been_requested.once
  end
end
