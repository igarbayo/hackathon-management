require "rails_helper"

RSpec.describe "Teams", type: :request do
  describe "POST /api/v1/teams" do
    it "creates the team with the user as owner" do
      user = create(:user)
      sign_in_as(user)

      post "/api/v1/teams",
           params: { name: "The Bytes", hackathon: { name: "HackUSC", starts_at: 1.day.from_now, ends_at: 3.days.from_now, timezone: "Europe/Madrid" } },
           headers: csrf_headers, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response["name"]).to eq("The Bytes")
      expect(json_response["code"]).to be_present

      membership = Membership.where(team_id: json_response["id"], user_id: user.id).first
      expect(membership.role).to eq("owner")
      expect(user.reload.last_team_id.to_s).to eq(json_response["id"])
    end
  end

  describe "POST /api/v1/teams/join" do
    it "creates a member membership with the code" do
      team = create(:team)
      user = create(:user)
      sign_in_as(user)

      post "/api/v1/teams/join", params: { code: team.code }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(Membership.where(team_id: team.id, user_id: user.id).first.role).to eq("member")
      expect(user.reload.last_team_id).to eq(team.id)
    end

    it "accepts the code formatted with a hyphen" do
      team = create(:team)
      user = create(:user)
      sign_in_as(user)

      post "/api/v1/teams/join", params: { code: team.formatted_code }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:ok)
    end

    it "is idempotent if they were already a member" do
      team = create(:team)
      user = create(:user)
      create(:membership, team: team, user: user, role: "member")
      sign_in_as(user)

      post "/api/v1/teams/join", params: { code: team.code }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(Membership.where(team_id: team.id, user_id: user.id).count).to eq(1)
    end

    it "404 with a code that does not exist (without revealing anything else)" do
      user = create(:user)
      sign_in_as(user)

      post "/api/v1/teams/join", params: { code: "ZZZZZZZZ" }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/teams/:id" do
    it "404 if the user is not a member (it does not reveal that the team exists)" do
      team = create(:team)
      outsider = create(:user)
      sign_in_as(outsider)

      get "/api/v1/teams/#{team.id}"

      expect(response).to have_http_status(:not_found)
    end

    it "200 with the team data if they are a member" do
      membership = create(:membership)
      sign_in_as(membership.user)

      get "/api/v1/teams/#{membership.team.id}"

      expect(response).to have_http_status(:ok)
      expect(json_response["id"]).to eq(membership.team.id.to_s)
    end

    it "remembers the team as the last opened one (RF-TEAM-013)" do
      membership = create(:membership)
      sign_in_as(membership.user)

      get "/api/v1/teams/#{membership.team.id}"

      expect(membership.user.reload.last_team_id).to eq(membership.team.id)
    end

    it "does not remember it if the request comes with a token, not a session" do
      membership = create(:membership)
      result = Pat::Create.call(membership: membership, name: "CLI", preset: "observe")

      get "/api/v1/teams/#{membership.team.id}", headers: { "Authorization" => "Bearer #{result.raw_token}" }

      expect(response).to have_http_status(:ok)
      expect(membership.user.reload.last_team_id).to be_nil
    end
  end

  describe "PATCH /api/v1/teams/:id" do
    it "only the owner can edit" do
      membership = create(:membership, role: "member")
      sign_in_as(membership.user)

      patch "/api/v1/teams/#{membership.team.id}", params: { name: "New name" }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it "the owner can change the name and the challenge_text" do
      membership = create(:membership, :owner)
      sign_in_as(membership.user)

      patch "/api/v1/teams/#{membership.team.id}",
            params: { name: "New name", hackathon: { challenge_text: "Build X" } },
            headers: csrf_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response["name"]).to eq("New name")
      expect(json_response["hackathon"]["challenge_text"]).to eq("Build X")
    end
  end

  describe "POST /api/v1/teams/:id/code/rotate" do
    it "generates a different code and the previous one stops working" do
      membership = create(:membership, :owner)
      sign_in_as(membership.user)
      old_code = membership.team.code

      post "/api/v1/teams/#{membership.team.id}/code/rotate", headers: csrf_headers

      expect(response).to have_http_status(:ok)
      expect(json_response["code"]).not_to eq(old_code)

      other_user = create(:user)
      sign_in_as(other_user)
      post "/api/v1/teams/join", params: { code: old_code }, headers: csrf_headers, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/teams/:id" do
    it "requires typing the team name to confirm" do
      membership = create(:membership, :owner)
      sign_in_as(membership.user)

      delete "/api/v1/teams/#{membership.team.id}", params: { confirm_name: "nombre incorrecto" }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(membership.team.reload.deleted_at).to be_nil
    end

    it "soft-deletes the team when the name matches" do
      membership = create(:membership, :owner)
      sign_in_as(membership.user)

      delete "/api/v1/teams/#{membership.team.id}", params: { confirm_name: membership.team.name }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:no_content)
      expect(membership.team.reload.deleted_at).to be_present
    end

    it "a member cannot delete the team" do
      membership = create(:membership, role: "member")
      sign_in_as(membership.user)

      delete "/api/v1/teams/#{membership.team.id}", params: { confirm_name: membership.team.name }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end
end
