require "rails_helper"

# Each domain write fires the right webhook
# (12-acceso-programatico.md#webhooks-salientes#eventos).
RSpec.describe "Firing webhook events", type: :request do
  def owner_with_webhook(*events)
    owner = create(:membership, :owner)
    create(:outbound_webhook, team: owner.team, events: events)
    owner
  end

  it "milestone.created and milestone.updated" do
    owner = owner_with_webhook("milestone.created", "milestone.updated")
    sign_in_as(owner.user)

    post "/api/v1/teams/#{owner.team.id}/milestones", params: { title: "Demo", kind: "demo", due_at: 2.days.from_now }, headers: csrf_headers, as: :json
    id = json_response["id"]
    expect(Webhooks::DeliverJob.jobs.size).to eq(1)

    patch "/api/v1/teams/#{owner.team.id}/milestones/#{id}", params: { title: "Final demo" }, headers: csrf_headers, as: :json
    expect(Webhooks::DeliverJob.jobs.size).to eq(2)
  end

  it "feature.created, feature.updated and feature.status_changed" do
    owner = owner_with_webhook("feature.created", "feature.updated", "feature.status_changed")
    sign_in_as(owner.user)

    post "/api/v1/teams/#{owner.team.id}/features", params: { title: "F" }, headers: csrf_headers, as: :json
    key = json_response["key"]
    expect(Webhooks::DeliverJob.jobs.size).to eq(1)

    patch "/api/v1/teams/#{owner.team.id}/features/#{key}", params: { status: "in_progress" }, headers: csrf_headers, as: :json
    # feature.updated + feature.status_changed at once
    expect(Webhooks::DeliverJob.jobs.size).to eq(3)
  end

  it "feature.assigned when assignee_ids change" do
    owner = owner_with_webhook("feature.assigned")
    feature = create(:feature, team: owner.team)
    sign_in_as(owner.user)

    patch "/api/v1/teams/#{owner.team.id}/features/#{feature.key}", params: { assignee_ids: [ owner.id.to_s ] }, headers: csrf_headers, as: :json

    expect(Webhooks::DeliverJob.jobs.size).to eq(1)
  end

  it "activity.created for a system event, never for claude_code" do
    owner = owner_with_webhook("activity.created")

    create(:activity_event, team: owner.team, source: "system", kind: "member_joined", dedupe_key: "s1")
    expect(Webhooks::DeliverJob.jobs.size).to eq(1)

    create(:activity_event, :claude_turn, team: owner.team, dedupe_key: "s2")
    expect(Webhooks::DeliverJob.jobs.size).to eq(1)
  end

  it "analysis.succeeded" do
    owner = owner_with_webhook("analysis.succeeded")
    stub_request(:post, /generativelanguage\.googleapis\.com/).to_return(
      status: 200,
      body: {
        candidates: [ { content: { parts: [ { text: { summary: "ok", coverage: [], orphan_features: [], gaps: [], risks: [] }.to_json } ] } } ],
        usageMetadata: { promptTokenCount: 10, candidatesTokenCount: 5 }
      }.to_json,
      headers: { "Content-Type" => "application/json" }
    )
    owner.user.update!(gemini_api_key: "test-key")

    analysis = Analysis::Enqueue.call(team: owner.team, trigger: "manual")
    Analysis::RunJob.new.perform(analysis.id.to_s)

    expect(Webhooks::DeliverJob.jobs.size).to eq(1)
  end
end
