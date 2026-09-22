require "rails_helper"

RSpec.describe "Team members", type: :request do
  describe "GET /api/v1/teams/:team_id/members" do
    it "lista los miembros con rol y estado de Claude Code" do
      owner = create(:membership, :owner)
      create(:membership, team: owner.team)
      sign_in_as(owner.user)

      get "/api/v1/teams/#{owner.team.id}/members"

      expect(response).to have_http_status(:ok)
      expect(json_response["data"].size).to eq(2)
    end
  end

  describe "PATCH /api/v1/teams/:team_id/members/:id" do
    it "un member no puede cambiar el role de otro" do
      owner = create(:membership, :owner)
      member = create(:membership, team: owner.team)
      sign_in_as(member.user)

      patch "/api/v1/teams/#{owner.team.id}/members/#{owner.id}", params: { role: "member" }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it "el owner puede cambiar el role de otro miembro" do
      owner = create(:membership, :owner)
      member = create(:membership, team: owner.team)
      sign_in_as(owner.user)

      patch "/api/v1/teams/#{owner.team.id}/members/#{member.id}", params: { role: "owner" }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(member.reload.role).to eq("owner")
    end

    it "cualquier miembro puede cambiar su propio display_name" do
      owner = create(:membership, :owner)
      member = create(:membership, team: owner.team)
      sign_in_as(member.user)

      patch "/api/v1/teams/#{owner.team.id}/members/#{member.id}", params: { display_name: "Mote" }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(member.reload.display_name).to eq("Mote")
    end
  end

  describe "DELETE /api/v1/teams/:team_id/members/:id" do
    it "un miembro puede salir del equipo" do
      owner = create(:membership, :owner)
      member = create(:membership, team: owner.team)
      sign_in_as(member.user)

      delete "/api/v1/teams/#{owner.team.id}/members/#{member.id}", headers: csrf_headers

      expect(response).to have_http_status(:no_content)
    end

    it "no deja expulsar al único owner" do
      owner = create(:membership, :owner)
      other_member = create(:membership, team: owner.team)
      sign_in_as(other_member.user)

      delete "/api/v1/teams/#{owner.team.id}/members/#{owner.id}", headers: csrf_headers

      expect(response).to have_http_status(:forbidden)
    end

    it "un member no puede expulsar a otro member" do
      create(:membership, :owner, team: (team = create(:team)))
      member_a = create(:membership, team: team)
      member_b = create(:membership, team: team)
      sign_in_as(member_a.user)

      delete "/api/v1/teams/#{team.id}/members/#{member_b.id}", headers: csrf_headers

      expect(response).to have_http_status(:forbidden)
    end
  end
end
