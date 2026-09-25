require "rails_helper"

# RF-API-005: Idempotency-Key on POSTs.
RSpec.describe "Idempotency-Key", type: :request do
  it "repeating the same request with the same key returns the same response and does not create two objectives" do
    membership = create(:membership)
    token = Pat::Create.call(membership: membership, name: "Agente", preset: "full").raw_token
    headers = { "Authorization" => "Bearer #{token}", "Idempotency-Key" => "abc-123" }

    post "/api/v1/teams/#{membership.team.id}/objectives", params: { title: "One", priority: "must" }, headers: headers, as: :json
    first_body = response.body

    post "/api/v1/teams/#{membership.team.id}/objectives", params: { title: "One", priority: "must" }, headers: headers, as: :json

    expect(response.body).to eq(first_body)
    expect(response.headers["Idempotent-Replayed"]).to eq("true")
    expect(Objective.where(team_id: membership.team.id).count).to eq(1)
  end

  it "reusing the key with another body returns 422 idempotency_key_reused" do
    membership = create(:membership)
    token = Pat::Create.call(membership: membership, name: "Agente", preset: "full").raw_token
    headers = { "Authorization" => "Bearer #{token}", "Idempotency-Key" => "abc-123" }

    post "/api/v1/teams/#{membership.team.id}/objectives", params: { title: "One", priority: "must" }, headers: headers, as: :json
    post "/api/v1/teams/#{membership.team.id}/objectives", params: { title: "Another", priority: "should" }, headers: headers, as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(json_response["error"]["code"]).to eq("idempotency_key_reused")
  end

  it "without Idempotency-Key, each request creates its own objective" do
    membership = create(:membership)
    token = Pat::Create.call(membership: membership, name: "Agente", preset: "full").raw_token
    headers = { "Authorization" => "Bearer #{token}" }

    post "/api/v1/teams/#{membership.team.id}/objectives", params: { title: "One", priority: "must" }, headers: headers, as: :json
    post "/api/v1/teams/#{membership.team.id}/objectives", params: { title: "One", priority: "must" }, headers: headers, as: :json

    expect(Objective.where(team_id: membership.team.id).count).to eq(2)
  end
end
