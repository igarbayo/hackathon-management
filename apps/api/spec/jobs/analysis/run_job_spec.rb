require "rails_helper"

RSpec.describe Analysis::RunJob do
  around do |example|
    original_key = ENV["GEMINI_API_KEY"]
    original_model = ENV["GEMINI_MODEL"]
    ENV["GEMINI_API_KEY"] = "test-key"
    ENV["GEMINI_MODEL"] = "gemini-test-model"
    example.run
    ENV["GEMINI_API_KEY"] = original_key
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

  it "crea un AiAnalysis succeeded con el resultado posvalidado" do
    team = create(:team)
    stub_gemini(valid_output)
    analysis = enqueue(team)

    described_class.new.perform(analysis.id.to_s)

    analysis.reload
    expect(analysis.status).to eq("succeeded")
    expect(analysis.result["summary"]).to eq("Vais bien")
    expect(analysis.usage).to eq("input_tokens" => 500, "output_tokens" => 120)
    expect(analysis.prompt_version).to eq("coverage_v1")
  end

  it "no llama a la IA si el contexto no cambió desde el último análisis completado (skip)" do
    team = create(:team)
    stub = stub_gemini(valid_output)

    described_class.new.perform(enqueue(team).id.to_s)
    second = enqueue(team)
    described_class.new.perform(second.id.to_s)

    expect(stub).to have_been_requested.once
    expect(second.reload.status).to eq("skipped")
    expect(second.skip_reason).to eq("no_changes")
  end

  it "marca failed si la IA no devuelve un JSON que cumpla el schema, tras reintentar una vez" do
    team = create(:team)
    stub = stub_gemini({ "summary" => "falta todo lo demás" })
    analysis = enqueue(team)

    described_class.new.perform(analysis.id.to_s)

    expect(stub).to have_been_requested.times(2)
    expect(analysis.reload.status).to eq("failed")
  end

  it "no ejecuta dos análisis a la vez para el mismo equipo (lock)" do
    team = create(:team)
    analysis = enqueue(team)
    Analysis::Lock.acquire(team.id.to_s)

    described_class.new.perform(analysis.id.to_s)

    expect(analysis.reload.status).to eq("queued")
  end

  it "es idempotente: no vuelve a ejecutar un análisis que ya no está queued" do
    team = create(:team)
    stub = stub_gemini(valid_output)
    analysis = enqueue(team)
    described_class.new.perform(analysis.id.to_s)

    described_class.new.perform(analysis.id.to_s)

    expect(stub).to have_been_requested.once
  end
end
