require "rails_helper"

RSpec.describe "Personal access tokens", type: :request do
  describe "POST /api/v1/teams/:team_id/tokens" do
    it "creates a PAT for the member themselves and returns the plain value only once" do
      membership = create(:membership)
      sign_in_as(membership.user)

      post "/api/v1/teams/#{membership.team.id}/tokens", params: { name: "Mi CLI", preset: "observe" }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response["token"]).to start_with("hb_pat_")
      expect(json_response["scopes"]).to eq([ "read" ])
    end

    it "requires a session: a PAT cannot create another PAT" do
      membership = create(:membership)
      result = Pat::Create.call(membership: membership, name: "Existing", preset: "full")

      post "/api/v1/teams/#{membership.team.id}/tokens", params: { name: "New" },
                                                          headers: { "Authorization" => "Bearer #{result.raw_token}" }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(json_response["error"]["code"]).to eq("session_required")
    end
  end

  describe "GET /api/v1/teams/:team_id/tokens" do
    it "a regular member only sees their own" do
      membership = create(:membership)
      other = create(:membership, team: membership.team)
      create(:access_token, team: membership.team, membership: membership, name: "Mine")
      create(:access_token, team: membership.team, membership: other, name: "Someone else's")
      sign_in_as(membership.user)

      get "/api/v1/teams/#{membership.team.id}/tokens"

      expect(json_response["data"].map { |t| t["name"] }).to eq([ "Mine" ])
    end

    it "an owner sees everyone's, but never the value" do
      owner = create(:membership, :owner)
      member = create(:membership, team: owner.team)
      create(:access_token, team: owner.team, membership: member, name: "From a member")
      sign_in_as(owner.user)

      get "/api/v1/teams/#{owner.team.id}/tokens"

      expect(json_response["data"].map { |t| t["name"] }).to include("From a member")
      expect(json_response["data"].first).not_to have_key("token")
      expect(json_response["data"].first).not_to have_key("token_digest")
    end
  end

  describe "DELETE /api/v1/teams/:team_id/tokens/:id" do
    it "the owner of a token can revoke it" do
      membership = create(:membership)
      token = create(:access_token, team: membership.team, membership: membership)
      sign_in_as(membership.user)

      delete "/api/v1/teams/#{membership.team.id}/tokens/#{token.id}", headers: csrf_headers

      expect(response).to have_http_status(:no_content)
      expect(token.reload.revoked_at).to be_present
    end

    it "an owner can revoke another member's" do
      owner = create(:membership, :owner)
      member = create(:membership, team: owner.team)
      token = create(:access_token, team: owner.team, membership: member)
      sign_in_as(owner.user)

      delete "/api/v1/teams/#{owner.team.id}/tokens/#{token.id}", headers: csrf_headers

      expect(response).to have_http_status(:no_content)
    end

    it "a regular member cannot revoke someone else's" do
      membership = create(:membership)
      other = create(:membership, team: membership.team)
      token = create(:access_token, team: membership.team, membership: other)
      sign_in_as(membership.user)

      delete "/api/v1/teams/#{membership.team.id}/tokens/#{token.id}", headers: csrf_headers

      expect(response).to have_http_status(:forbidden)
    end
  end
end
