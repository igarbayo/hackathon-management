require "rails_helper"

# RF-API-006: every write made with a token leaves a trace in the feed with
# `via`. The same writes made from the web app do not have it.
RSpec.describe "via tracking (RF-API-006)", type: :request do
  def token_for(membership, preset: "full")
    Pat::Create.call(membership: membership, name: "Agente", preset: preset).raw_token
  end

  it "creating an objective with a token leaves a system/api_change event with via" do
    membership = create(:membership)
    token = token_for(membership)

    post "/api/v1/teams/#{membership.team.id}/objectives", params: { title: "New", priority: "must" }, headers: { "Authorization" => "Bearer #{token}" }, as: :json

    event = ActivityEvent.where(team_id: membership.team.id, kind: "api_change").first
    expect(event).to be_present
    expect(event.via["channel"]).to eq("api")
    expect(event.via["token_kind"]).to eq("pat")
    expect(event.payload["fields"]).to match_array(%w[title priority])
  end

  it "creating the same objective from the web app (session) leaves no api_change" do
    membership = create(:membership)
    sign_in_as(membership.user)

    post "/api/v1/teams/#{membership.team.id}/objectives", params: { title: "New", priority: "must" }, headers: csrf_headers, as: :json

    expect(ActivityEvent.where(team_id: membership.team.id, kind: "api_change").count).to eq(0)
  end

  it "changing a feature's status with a token leaves the feature_status_changed event with via, not a separate api_change" do
    membership = create(:membership)
    feature = create(:feature, team: membership.team, status: "idea")
    token = token_for(membership)

    patch "/api/v1/teams/#{membership.team.id}/features/#{feature.key}", params: { status: "in_progress" },
                                                                          headers: { "Authorization" => "Bearer #{token}" }, as: :json

    status_event = ActivityEvent.where(team_id: membership.team.id, kind: "feature_status_changed").first
    expect(status_event.via["token_kind"]).to eq("pat")
    expect(ActivityEvent.where(team_id: membership.team.id, kind: "api_change").count).to eq(0)
  end

  it "editing the title and the status at once leaves both events, each with its via" do
    membership = create(:membership)
    feature = create(:feature, team: membership.team, status: "idea")
    token = token_for(membership)

    patch "/api/v1/teams/#{membership.team.id}/features/#{feature.key}", params: { status: "in_progress", title: "New title" },
                                                                          headers: { "Authorization" => "Bearer #{token}" }, as: :json

    expect(ActivityEvent.where(team_id: membership.team.id, kind: "feature_status_changed").count).to eq(1)
    api_change = ActivityEvent.where(team_id: membership.team.id, kind: "api_change").first
    expect(api_change.payload["fields"]).to eq([ "title" ])
  end

  it "voting on an argument with a token leaves a trace" do
    membership = create(:membership)
    feature = create(:feature, team: membership.team)
    argument = feature.arguments.create!(kind: "pro", text: "Good idea", author_id: membership.user_id)
    token = token_for(membership)

    put "/api/v1/teams/#{membership.team.id}/features/#{feature.key}/arguments/#{argument.id}/vote",
        headers: { "Authorization" => "Bearer #{token}" }

    event = ActivityEvent.where(team_id: membership.team.id, kind: "api_change").first
    expect(event.payload["entity"]).to eq("argument")
    expect(event.via["token_prefix"]).to be_present
  end
end
