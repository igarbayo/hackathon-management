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
    { "summary" => "You are on track", "coverage" => [], "orphan_features" => [], "gaps" => [], "risks" => [] }
  end

  def enqueue(team, trigger: "manual")
    Analysis::Enqueue.call(team: team, trigger: trigger)
  end

  # RF-AI-021: with no requested_by, resolve_api_key uses the owner's key.
  def team_with_ai_key
    team = create(:team, :with_owner)
    team.memberships.first.user.update!(gemini_api_key: "test-key")
    team
  end

  it "creates a succeeded AiAnalysis with the post-validated result" do
    team = team_with_ai_key
    stub_gemini(valid_output)
    analysis = enqueue(team)

    described_class.new.perform(analysis.id.to_s)

    analysis.reload
    expect(analysis.status).to eq("succeeded")
    expect(analysis.result["summary"]).to eq("You are on track")
    expect(analysis.usage).to eq("input_tokens" => 500, "output_tokens" => 120)
    expect(analysis.prompt_version).to eq("coverage_v2")
  end

  it "for a manual run with requested_by, uses the requester's key and not the owner's" do
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

  it "does not call the AI if the context has not changed since the last completed analysis (skip)" do
    team = team_with_ai_key
    stub = stub_gemini(valid_output)

    described_class.new.perform(enqueue(team).id.to_s)
    second = enqueue(team)
    described_class.new.perform(second.id.to_s)

    expect(stub).to have_been_requested.once
    expect(second.reload.status).to eq("skipped")
    expect(second.skip_reason).to eq("no_changes")
  end

  it "marks skipped/no_api_key if nobody in the team has a Gemini key set up" do
    team = create(:team, :with_owner)
    analysis = enqueue(team)

    described_class.new.perform(analysis.id.to_s)

    expect(a_request(:post, /generativelanguage\.googleapis\.com/)).not_to have_been_made
    expect(analysis.reload.status).to eq("skipped")
    expect(analysis.skip_reason).to eq("no_api_key")
  end

  it "marks failed if the AI does not return JSON that matches the schema, after one retry" do
    team = team_with_ai_key
    stub = stub_gemini({ "summary" => "everything else is missing" })
    analysis = enqueue(team)

    described_class.new.perform(analysis.id.to_s)

    expect(stub).to have_been_requested.times(2)
    expect(analysis.reload.status).to eq("failed")
  end

  it "does not run two analyses at once for the same team (lock)" do
    team = team_with_ai_key
    analysis = enqueue(team)
    Analysis::Lock.acquire(team.id.to_s)

    described_class.new.perform(analysis.id.to_s)

    expect(analysis.reload.status).to eq("queued")
    # It waits for the running one instead of staying queued forever.
    expect(described_class.jobs.last["args"]).to eq([ analysis.id.to_s ])
    expect(described_class.jobs.last["at"]).to be_present
  end

  it "marks failed on an unexpected error, such as a Gemini timeout, and frees the lock" do
    team = team_with_ai_key
    stub_request(:post, /generativelanguage\.googleapis\.com/).to_timeout
    analysis = enqueue(team)

    described_class.new.perform(analysis.id.to_s)

    analysis.reload
    expect(analysis.status).to eq("failed")
    expect(analysis.error).to start_with("Faraday::")
    expect(Analysis::Lock.acquire(team.id.to_s)).to be true
  end

  it "is idempotent: does not run again an analysis that is no longer queued" do
    team = team_with_ai_key
    stub = stub_gemini(valid_output)
    analysis = enqueue(team)
    described_class.new.perform(analysis.id.to_s)

    described_class.new.perform(analysis.id.to_s)

    expect(stub).to have_been_requested.once
  end
end
