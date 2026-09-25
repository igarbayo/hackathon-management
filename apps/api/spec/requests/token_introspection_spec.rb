require "rails_helper"

RSpec.describe "GET /api/v1/token", type: :request do
  it "401 without Authorization" do
    get "/api/v1/token"

    expect(response).to have_http_status(:unauthorized)
  end

  it "returns the team, member, scopes and expiry of a PAT" do
    membership = create(:membership)
    result = Pat::Create.call(membership: membership, name: "My token", preset: "agent")

    get "/api/v1/token", headers: { "Authorization" => "Bearer #{result.raw_token}" }

    expect(response).to have_http_status(:ok)
    expect(json_response["kind"]).to eq("pat")
    expect(json_response["team"]["id"]).to eq(membership.team.id.to_s)
    expect(json_response["member"]["id"]).to eq(membership.id.to_s)
    expect(json_response["scopes"]).to include("features:write")
  end

  it "also works with a member token" do
    membership = create(:membership)
    membership.update!(claude_code_attributes: { token_digest: Digest::SHA256.hexdigest("hb_mt_x"), token_prefix: "hb_mt_x", privacy_level: "metadata" })

    get "/api/v1/token", headers: { "Authorization" => "Bearer hb_mt_x" }

    expect(response).to have_http_status(:ok)
    expect(json_response["kind"]).to eq("member")
  end
end
