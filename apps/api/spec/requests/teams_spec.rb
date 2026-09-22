require "rails_helper"

RSpec.describe "Teams", type: :request do
  describe "POST /api/v1/teams" do
    it "crea el equipo con el usuario como owner" do
      user = create(:user)
      sign_in_as(user)

      post "/api/v1/teams",
           params: { name: "Los Bytes", hackathon: { name: "HackUSC", starts_at: 1.day.from_now, ends_at: 3.days.from_now, timezone: "Europe/Madrid" } },
           headers: csrf_headers, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response["name"]).to eq("Los Bytes")
      expect(json_response["code"]).to be_present

      membership = Membership.where(team_id: json_response["id"], user_id: user.id).first
      expect(membership.role).to eq("owner")
    end
  end

  describe "POST /api/v1/teams/join" do
    it "crea una membresía member con el código" do
      team = create(:team)
      user = create(:user)
      sign_in_as(user)

      post "/api/v1/teams/join", params: { code: team.code }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(Membership.where(team_id: team.id, user_id: user.id).first.role).to eq("member")
    end

    it "acepta el código formateado con guion" do
      team = create(:team)
      user = create(:user)
      sign_in_as(user)

      post "/api/v1/teams/join", params: { code: team.formatted_code }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:ok)
    end

    it "es idempotente si ya era miembro" do
      team = create(:team)
      user = create(:user)
      create(:membership, team: team, user: user, role: "member")
      sign_in_as(user)

      post "/api/v1/teams/join", params: { code: team.code }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(Membership.where(team_id: team.id, user_id: user.id).count).to eq(1)
    end

    it "404 con un código que no existe (sin revelar nada más)" do
      user = create(:user)
      sign_in_as(user)

      post "/api/v1/teams/join", params: { code: "ZZZZZZZZ" }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/teams/:id" do
    it "404 si el usuario no es miembro (no revela que el equipo existe)" do
      team = create(:team)
      outsider = create(:user)
      sign_in_as(outsider)

      get "/api/v1/teams/#{team.id}"

      expect(response).to have_http_status(:not_found)
    end

    it "200 con los datos del equipo si es miembro" do
      membership = create(:membership)
      sign_in_as(membership.user)

      get "/api/v1/teams/#{membership.team.id}"

      expect(response).to have_http_status(:ok)
      expect(json_response["id"]).to eq(membership.team.id.to_s)
    end
  end

  describe "PATCH /api/v1/teams/:id" do
    it "solo el owner puede editar" do
      membership = create(:membership, role: "member")
      sign_in_as(membership.user)

      patch "/api/v1/teams/#{membership.team.id}", params: { name: "Nuevo nombre" }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it "el owner puede cambiar el nombre y el challenge_text" do
      membership = create(:membership, :owner)
      sign_in_as(membership.user)

      patch "/api/v1/teams/#{membership.team.id}",
            params: { name: "Nuevo nombre", hackathon: { challenge_text: "Construir X" } },
            headers: csrf_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response["name"]).to eq("Nuevo nombre")
      expect(json_response["hackathon"]["challenge_text"]).to eq("Construir X")
    end
  end

  describe "POST /api/v1/teams/:id/code/rotate" do
    it "genera un código distinto y el anterior deja de servir" do
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
    it "exige escribir el nombre del equipo para confirmar" do
      membership = create(:membership, :owner)
      sign_in_as(membership.user)

      delete "/api/v1/teams/#{membership.team.id}", params: { confirm_name: "nombre incorrecto" }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(membership.team.reload.deleted_at).to be_nil
    end

    it "borra lógicamente el equipo cuando el nombre coincide" do
      membership = create(:membership, :owner)
      sign_in_as(membership.user)

      delete "/api/v1/teams/#{membership.team.id}", params: { confirm_name: membership.team.name }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:no_content)
      expect(membership.team.reload.deleted_at).to be_present
    end

    it "un member no puede borrar el equipo" do
      membership = create(:membership, role: "member")
      sign_in_as(membership.user)

      delete "/api/v1/teams/#{membership.team.id}", params: { confirm_name: membership.team.name }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end
end
