require "rails_helper"

RSpec.describe "Apps conectadas del equipo (RF-API-021)", type: :request do
  describe "GET /api/v1/teams/:team_id/oauth_connections" do
    it "un owner ve las conexiones OAuth de cualquier miembro del equipo" do
      owner = create(:membership, :owner)
      other_member = create(:membership, team: owner.team)
      client = create(:oauth_client)
      token = create(:access_token, :oauth, team: owner.team, user_id: other_member.user_id, oauth_client: client, refresh_family_id: "fam-1")
      sign_in_as(owner.user)

      get "/api/v1/teams/#{owner.team.id}/oauth_connections", headers: csrf_headers

      expect(response).to have_http_status(:ok)
      expect(json_response["data"].size).to eq(1)
      connection = json_response["data"].first
      expect(connection["id"]).to eq("fam-1")
      expect(connection["user"]["display_name"]).to eq(other_member.display_name)
      expect(connection["client"]["id"]).to eq(client.id.to_s)
      _ = token
    end

    it "un miembro normal no puede verlas" do
      member = create(:membership)
      sign_in_as(member.user)

      get "/api/v1/teams/#{member.team.id}/oauth_connections", headers: csrf_headers

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE /api/v1/teams/:team_id/oauth_connections/:id" do
    it "un owner revoca la conexión de otro miembro (toda la familia)" do
      owner = create(:membership, :owner)
      other_member = create(:membership, team: owner.team)
      create(:access_token, :oauth, team: owner.team, user_id: other_member.user_id, refresh_family_id: "fam-2")
      create(:access_token, :oauth, team: owner.team, user_id: other_member.user_id, refresh_family_id: "fam-2")
      sign_in_as(owner.user)

      delete "/api/v1/teams/#{owner.team.id}/oauth_connections/fam-2", headers: csrf_headers

      expect(response).to have_http_status(:no_content)
      expect(AccessToken.where(refresh_family_id: "fam-2", revoked_at: nil)).to be_empty
    end

    it "404 si la familia no es de este equipo" do
      owner = create(:membership, :owner)
      other_team = create(:team)
      create(:access_token, :oauth, team: other_team, refresh_family_id: "fam-3")
      sign_in_as(owner.user)

      delete "/api/v1/teams/#{owner.team.id}/oauth_connections/fam-3", headers: csrf_headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
