require "rails_helper"

RSpec.describe "Tokens de acceso personal", type: :request do
  describe "POST /api/v1/teams/:team_id/tokens" do
    it "crea un PAT para el propio miembro y devuelve el valor en claro una sola vez" do
      membership = create(:membership)
      sign_in_as(membership.user)

      post "/api/v1/teams/#{membership.team.id}/tokens", params: { name: "Mi CLI", preset: "observar" }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response["token"]).to start_with("hb_pat_")
      expect(json_response["scopes"]).to eq([ "read" ])
    end

    it "exige sesión: un PAT no puede crear otro PAT" do
      membership = create(:membership)
      result = Pat::Create.call(membership: membership, name: "Existente", preset: "completo")

      post "/api/v1/teams/#{membership.team.id}/tokens", params: { name: "Nuevo" },
                                                          headers: { "Authorization" => "Bearer #{result.raw_token}" }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(json_response["error"]["code"]).to eq("session_required")
    end
  end

  describe "GET /api/v1/teams/:team_id/tokens" do
    it "un miembro normal solo ve los suyos" do
      membership = create(:membership)
      other = create(:membership, team: membership.team)
      create(:access_token, team: membership.team, membership: membership, name: "Mío")
      create(:access_token, team: membership.team, membership: other, name: "De otro")
      sign_in_as(membership.user)

      get "/api/v1/teams/#{membership.team.id}/tokens"

      expect(json_response["data"].map { |t| t["name"] }).to eq([ "Mío" ])
    end

    it "un owner ve los de todos, pero nunca el valor" do
      owner = create(:membership, :owner)
      member = create(:membership, team: owner.team)
      create(:access_token, team: owner.team, membership: member, name: "De un miembro")
      sign_in_as(owner.user)

      get "/api/v1/teams/#{owner.team.id}/tokens"

      expect(json_response["data"].map { |t| t["name"] }).to include("De un miembro")
      expect(json_response["data"].first).not_to have_key("token")
      expect(json_response["data"].first).not_to have_key("token_digest")
    end
  end

  describe "DELETE /api/v1/teams/:team_id/tokens/:id" do
    it "el dueño puede revocar el suyo" do
      membership = create(:membership)
      token = create(:access_token, team: membership.team, membership: membership)
      sign_in_as(membership.user)

      delete "/api/v1/teams/#{membership.team.id}/tokens/#{token.id}", headers: csrf_headers

      expect(response).to have_http_status(:no_content)
      expect(token.reload.revoked_at).to be_present
    end

    it "un owner puede revocar el de otro miembro" do
      owner = create(:membership, :owner)
      member = create(:membership, team: owner.team)
      token = create(:access_token, team: owner.team, membership: member)
      sign_in_as(owner.user)

      delete "/api/v1/teams/#{owner.team.id}/tokens/#{token.id}", headers: csrf_headers

      expect(response).to have_http_status(:no_content)
    end

    it "un miembro normal no puede revocar el de otro" do
      membership = create(:membership)
      other = create(:membership, team: membership.team)
      token = create(:access_token, team: membership.team, membership: other)
      sign_in_as(membership.user)

      delete "/api/v1/teams/#{membership.team.id}/tokens/#{token.id}", headers: csrf_headers

      expect(response).to have_http_status(:forbidden)
    end
  end
end
