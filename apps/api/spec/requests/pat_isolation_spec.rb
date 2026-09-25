require "rails_helper"

# RNF-API-002: a PAT behaves like any other channel regarding isolation between
# teams and scopes.
RSpec.describe "Isolation and scopes with a PAT (RNF-API-002)", type: :request do
  it "404 if the token belongs to another team, even with all scopes" do
    membership_a = create(:membership)
    team_b = create(:team)
    objective_b = create(:objective, team: team_b)
    result = Pat::Create.call(membership: membership_a, name: "Completo", preset: "full")

    get "/api/v1/teams/#{team_b.id}/objectives", headers: { "Authorization" => "Bearer #{result.raw_token}" }
    expect(response).to have_http_status(:not_found)

    patch "/api/v1/teams/#{team_b.id}/objectives/#{objective_b.id}", params: { title: "hacked" },
                                                                       headers: { "Authorization" => "Bearer #{result.raw_token}" }, as: :json
    expect(response).to have_http_status(:not_found)
    expect(objective_b.reload.title).not_to eq("hacked")
  end

  it "403 insufficient_scope if the token is missing the scope, even for the right team" do
    membership = create(:membership)
    result = Pat::Create.call(membership: membership, name: "Read only", preset: "observe")

    post "/api/v1/teams/#{membership.team.id}/objectives", params: { title: "New objective" },
                                                             headers: { "Authorization" => "Bearer #{result.raw_token}" }, as: :json

    expect(response).to have_http_status(:forbidden)
    expect(json_response["error"]["code"]).to eq("insufficient_scope")
    expect(json_response["error"]["details"]["required_scope"]).to eq("objectives:write")
  end

  it "200 if the token belongs to the right team and has the scope" do
    membership = create(:membership)
    result = Pat::Create.call(membership: membership, name: "Agente", preset: "agent")

    post "/api/v1/teams/#{membership.team.id}/features", params: { title: "Nueva feature" },
                                                           headers: { "Authorization" => "Bearer #{result.raw_token}" }, as: :json

    expect(response).to have_http_status(:created)
  end

  it "no session_only endpoint accepts Bearer, not even with all scopes" do
    membership = create(:membership)
    feature = create(:feature, team: membership.team)
    result = Pat::Create.call(membership: membership, name: "Completo", preset: "full")

    delete "/api/v1/teams/#{membership.team.id}/features/#{feature.key}", headers: { "Authorization" => "Bearer #{result.raw_token}" }

    expect(response).to have_http_status(:forbidden)
    expect(json_response["error"]["code"]).to eq("session_required")
  end

  it "400 if the request has both a session cookie and a Bearer" do
    membership = create(:membership)
    result = Pat::Create.call(membership: membership, name: "Token", preset: "observe")
    sign_in_as(membership.user)

    get "/api/v1/teams/#{membership.team.id}/objectives", headers: { "Authorization" => "Bearer #{result.raw_token}" }

    expect(response).to have_http_status(:bad_request)
  end

  it "401 if the token is revoked" do
    membership = create(:membership)
    result = Pat::Create.call(membership: membership, name: "Token", preset: "full")
    result.record.update!(revoked_at: Time.current, revoke_reason: "manual")

    get "/api/v1/teams/#{membership.team.id}/objectives", headers: { "Authorization" => "Bearer #{result.raw_token}" }

    expect(response).to have_http_status(:unauthorized)
  end

  it "429 when going over the writes per minute limit (RNF-API-001)" do
    membership = create(:membership)
    result = Pat::Create.call(membership: membership, name: "Agente", preset: "agent")
    headers = { "Authorization" => "Bearer #{result.raw_token}" }

    30.times { post "/api/v1/teams/#{membership.team.id}/features", params: { title: "F" }, headers: headers, as: :json }
    post "/api/v1/teams/#{membership.team.id}/features", params: { title: "F" }, headers: headers, as: :json

    expect(response).to have_http_status(:too_many_requests)
  end
end
