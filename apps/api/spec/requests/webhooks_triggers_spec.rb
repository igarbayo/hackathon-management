require "rails_helper"

# Que cada escritura de dominio dispare el webhook correcto
# (12-acceso-programatico.md#webhooks-salientes#eventos).
RSpec.describe "Disparo de eventos de webhooks", type: :request do
  def owner_with_webhook(*events)
    owner = create(:membership, :owner)
    create(:outbound_webhook, team: owner.team, events: events)
    owner
  end

  it "milestone.created y milestone.updated" do
    owner = owner_with_webhook("milestone.created", "milestone.updated")
    sign_in_as(owner.user)

    post "/api/v1/teams/#{owner.team.id}/milestones", params: { title: "Demo", kind: "demo", due_at: 2.days.from_now }, headers: csrf_headers, as: :json
    id = json_response["id"]
    expect(Webhooks::DeliverJob.jobs.size).to eq(1)

    patch "/api/v1/teams/#{owner.team.id}/milestones/#{id}", params: { title: "Demo final" }, headers: csrf_headers, as: :json
    expect(Webhooks::DeliverJob.jobs.size).to eq(2)
  end

  it "feature.created, feature.updated y feature.status_changed" do
    owner = owner_with_webhook("feature.created", "feature.updated", "feature.status_changed")
    sign_in_as(owner.user)

    post "/api/v1/teams/#{owner.team.id}/features", params: { title: "F" }, headers: csrf_headers, as: :json
    key = json_response["key"]
    expect(Webhooks::DeliverJob.jobs.size).to eq(1)

    patch "/api/v1/teams/#{owner.team.id}/features/#{key}", params: { status: "in_progress" }, headers: csrf_headers, as: :json
    # feature.updated + feature.status_changed a la vez
    expect(Webhooks::DeliverJob.jobs.size).to eq(3)
  end

  it "feature.assigned al cambiar assignee_ids" do
    owner = owner_with_webhook("feature.assigned")
    feature = create(:feature, team: owner.team)
    sign_in_as(owner.user)

    patch "/api/v1/teams/#{owner.team.id}/features/#{feature.key}", params: { assignee_ids: [ owner.id.to_s ] }, headers: csrf_headers, as: :json

    expect(Webhooks::DeliverJob.jobs.size).to eq(1)
  end

  it "activity.created para un evento system, nunca para claude_code" do
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
