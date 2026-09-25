require "rails_helper"

RSpec.describe Attribution::SuggestForTeam do
  around do |example|
    original_model = ENV["GEMINI_MODEL"]
    ENV["GEMINI_MODEL"] = "gemini-test-model"
    example.run
    ENV["GEMINI_MODEL"] = original_model
  end

  def stub_gemini(data)
    stub_request(:post, /generativelanguage\.googleapis\.com/).to_return(
      status: 200,
      body: { candidates: [ { content: { parts: [ { text: data.to_json } ] } } ], usageMetadata: {} }.to_json,
      headers: { "Content-Type" => "application/json" }
    )
  end

  # RF-AI-021: ask_ai uses the team owner's key (background job, no actor).
  def make_owner_with_key(team)
    create(:membership, :owner, team: team).user.update!(gemini_api_key: "test-key")
  end

  it "does nothing if ai_attribution_enabled is turned off" do
    team = create(:team)
    team.update!(settings: team.settings.merge("ai_attribution_enabled" => false))
    create(:activity_event, :github_commit, team: team)

    described_class.call(team)

    expect(a_request(:post, /generativelanguage/)).not_to have_been_made
  end

  it "uses the heuristic without calling the AI if the actor has a single in_progress feature" do
    membership = create(:membership)
    team = membership.team
    feature = create(:feature, team: team, status: "in_progress", assignee_ids: [ membership.user_id ])
    event = create(:activity_event, :github_commit, team: team, branch: "f-x-something", actor: { "user_id" => membership.user_id.to_s })

    described_class.call(team)

    expect(a_request(:post, /generativelanguage/)).not_to have_been_made
    event.reload
    expect(event.attribution.feature_id).to eq(feature.id)
    expect(event.attribution.method).to eq("ai")
    expect(event.attribution.status).to eq("suggested")
    expect(event.attribution.confidence).to eq(0.6)
  end

  it "calls the AI for the groups the heuristic does not resolve and applies confidence >= 0.5" do
    membership = create(:membership)
    team = membership.team
    make_owner_with_key(team)
    feature = create(:feature, team: team)
    event = create(:activity_event, :github_commit, team: team, actor: { "user_id" => membership.user_id.to_s })

    stub_gemini({ "assignments" => [ { "group_id" => event_group_id(event), "feature_key" => feature.key, "confidence" => 0.8, "reason" => "the title matches" } ] })

    described_class.call(team)

    event.reload
    expect(event.attribution.feature_id).to eq(feature.id)
    expect(event.attribution.confidence).to eq(0.8)
  end

  it "with no owner Gemini key, does not call the AI and marks the groups as attempted" do
    membership = create(:membership)
    team = membership.team
    create(:membership, :owner, team: team)
    feature = create(:feature, team: team)
    event = create(:activity_event, :github_commit, team: team, actor: { "user_id" => membership.user_id.to_s })
    stub_gemini({ "assignments" => [ { "group_id" => event_group_id(event), "feature_key" => feature.key, "confidence" => 0.8, "reason" => "x" } ] })

    described_class.call(team)

    expect(a_request(:post, /generativelanguage/)).not_to have_been_made
    event.reload
    expect(event.attribution).to be_nil
    expect(event.ai_suggestion_attempted_at).to be_present
  end

  it "does not attribute and sets ai_suggestion_attempted_at if confidence < 0.5" do
    membership = create(:membership)
    team = membership.team
    make_owner_with_key(team)
    feature = create(:feature, team: team)
    event = create(:activity_event, :github_commit, team: team, actor: { "user_id" => membership.user_id.to_s })

    stub_gemini({ "assignments" => [ { "group_id" => event_group_id(event), "feature_key" => feature.key, "confidence" => 0.3, "reason" => "not sure" } ] })

    described_class.call(team)

    event.reload
    expect(event.attribution).to be_nil
    expect(event.ai_suggestion_attempted_at).to be_present
  end

  it "does not retry a group already attempted with no new events" do
    membership = create(:membership)
    team = membership.team
    event = create(:activity_event, :github_commit, team: team, actor: { "user_id" => membership.user_id.to_s })
    event.set(ai_suggestion_attempted_at: Time.current)

    described_class.call(team)

    expect(a_request(:post, /generativelanguage/)).not_to have_been_made
  end

  it "never suggests again a feature already rejected for that group" do
    membership = create(:membership)
    team = membership.team
    make_owner_with_key(team)
    rejected_feature = create(:feature, team: team)
    event = create(:activity_event, :github_commit, team: team, actor: { "user_id" => membership.user_id.to_s })
    event.build_attribution(method: "ai", status: "rejected", rejected_feature_ids: [ rejected_feature.id ])
    event.save!

    stub = stub_gemini({ "assignments" => [ { "group_id" => event_group_id(event), "feature_key" => rejected_feature.key, "confidence" => 0.9, "reason" => "x" } ] })

    described_class.call(team)

    expect(stub).to have_been_requested
    event.reload
    expect(event.attribution.feature_id).to be_nil
  end

  def event_group_id(event)
    Digest::SHA256.hexdigest([ event.actor["user_id"], event.branch, event.session_ref ].join("|"))[0, 12]
  end
end
