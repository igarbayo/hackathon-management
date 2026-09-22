require "rails_helper"

RSpec.describe Attribution::SuggestForTeam do
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
      body: { candidates: [{ content: { parts: [{ text: data.to_json }] } }], usageMetadata: {} }.to_json,
      headers: { "Content-Type" => "application/json" }
    )
  end

  it "no hace nada si ai_attribution_enabled está desactivado" do
    team = create(:team)
    team.update!(settings: team.settings.merge("ai_attribution_enabled" => false))
    create(:activity_event, :github_commit, team: team)

    described_class.call(team)

    expect(a_request(:post, /generativelanguage/)).not_to have_been_made
  end

  it "usa la heurística sin llamar a la IA si el actor tiene una sola feature in_progress" do
    membership = create(:membership)
    team = membership.team
    feature = create(:feature, team: team, status: "in_progress", assignee_ids: [membership.user_id])
    event = create(:activity_event, :github_commit, team: team, branch: "f-x-algo", actor: { "user_id" => membership.user_id.to_s })

    described_class.call(team)

    expect(a_request(:post, /generativelanguage/)).not_to have_been_made
    event.reload
    expect(event.attribution.feature_id).to eq(feature.id)
    expect(event.attribution.method).to eq("ai")
    expect(event.attribution.status).to eq("suggested")
    expect(event.attribution.confidence).to eq(0.6)
  end

  it "llama a la IA para los grupos que no resuelve la heurística y aplica confidence >= 0.5" do
    membership = create(:membership)
    team = membership.team
    feature = create(:feature, team: team)
    event = create(:activity_event, :github_commit, team: team, actor: { "user_id" => membership.user_id.to_s })

    stub_gemini({ "assignments" => [{ "group_id" => event_group_id(event), "feature_key" => feature.key, "confidence" => 0.8, "reason" => "coincide el título" }] })

    described_class.call(team)

    event.reload
    expect(event.attribution.feature_id).to eq(feature.id)
    expect(event.attribution.confidence).to eq(0.8)
  end

  it "no atribuye y marca ai_suggestion_attempted_at si confidence < 0.5" do
    membership = create(:membership)
    team = membership.team
    feature = create(:feature, team: team)
    event = create(:activity_event, :github_commit, team: team, actor: { "user_id" => membership.user_id.to_s })

    stub_gemini({ "assignments" => [{ "group_id" => event_group_id(event), "feature_key" => feature.key, "confidence" => 0.3, "reason" => "no seguro" }] })

    described_class.call(team)

    event.reload
    expect(event.attribution).to be_nil
    expect(event.ai_suggestion_attempted_at).to be_present
  end

  it "no vuelve a intentar un grupo ya intentado sin eventos nuevos" do
    membership = create(:membership)
    team = membership.team
    event = create(:activity_event, :github_commit, team: team, actor: { "user_id" => membership.user_id.to_s })
    event.set(ai_suggestion_attempted_at: Time.current)

    described_class.call(team)

    expect(a_request(:post, /generativelanguage/)).not_to have_been_made
  end

  it "nunca vuelve a sugerir una feature ya rechazada para ese grupo" do
    membership = create(:membership)
    team = membership.team
    rejected_feature = create(:feature, team: team)
    event = create(:activity_event, :github_commit, team: team, actor: { "user_id" => membership.user_id.to_s })
    event.build_attribution(method: "ai", status: "rejected", rejected_feature_ids: [rejected_feature.id])
    event.save!

    stub = stub_gemini({ "assignments" => [{ "group_id" => event_group_id(event), "feature_key" => rejected_feature.key, "confidence" => 0.9, "reason" => "x" }] })

    described_class.call(team)

    expect(stub).to have_been_requested
    event.reload
    expect(event.attribution.feature_id).to be_nil
  end

  def event_group_id(event)
    Digest::SHA256.hexdigest([event.actor["user_id"], event.branch, event.session_ref].join("|"))[0, 12]
  end
end
