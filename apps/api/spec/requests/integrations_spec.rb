require "rails_helper"

RSpec.describe "Tokens de integración", type: :request do
  describe "POST /api/v1/teams/:team_id/integrations" do
    it "un owner crea una integración" do
      owner = create(:membership, :owner)
      sign_in_as(owner.user)

      post "/api/v1/teams/#{owner.team.id}/integrations", params: { name: "Bot de Slack", scopes: ["features:write"] }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response["token"]).to start_with("hb_it_")
    end

    it "un miembro normal no puede crear integraciones" do
      member = create(:membership)
      sign_in_as(member.user)

      post "/api/v1/teams/#{member.team.id}/integrations", params: { name: "Bot" }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it "session_only: un token no puede crear integraciones" do
      owner = create(:membership, :owner)
      token = Pat::Create.call(membership: owner, name: "Completo", preset: "completo").raw_token

      post "/api/v1/teams/#{owner.team.id}/integrations", params: { name: "Bot" }, headers: { "Authorization" => "Bearer #{token}" }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(json_response["error"]["code"]).to eq("session_required")
    end
  end

  describe "DELETE /api/v1/teams/:team_id/integrations/:id" do
    it "un owner puede revocarla" do
      owner = create(:membership, :owner)
      integration = create(:access_token, :integration, team: owner.team, created_by_id: owner.user_id)
      sign_in_as(owner.user)

      delete "/api/v1/teams/#{owner.team.id}/integrations/#{integration.id}", headers: csrf_headers

      expect(response).to have_http_status(:no_content)
      expect(integration.reload.revoked_at).to be_present
    end
  end

  describe "usar un token de integración en la API de dominio" do
    it "crea una feature con la integración como actor, sin persona" do
      owner = create(:membership, :owner)
      result = Integration::Create.call(team: owner.team, created_by: owner.user, name: "Bot", scopes: ["features:write"])

      post "/api/v1/teams/#{owner.team.id}/features", params: { title: "Hecho por el bot" }, headers: { "Authorization" => "Bearer #{result.raw_token}" }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response["created_by_id"]).to be_nil

      event = ActivityEvent.where(team_id: owner.team.id, kind: "api_change").first
      expect(event.actor["integration_id"]).to eq(result.record.id.to_s)
      expect(event.via["token_kind"]).to eq("integration")
    end

    it "no puede votar ni añadir argumentos (acción de una persona)" do
      owner = create(:membership, :owner)
      feature = create(:feature, team: owner.team)
      result = Integration::Create.call(team: owner.team, created_by: owner.user, name: "Bot", scopes: ["arguments:write"])

      post "/api/v1/teams/#{owner.team.id}/features/#{feature.key}/arguments", params: { kind: "pro", text: "..." },
                                                                                headers: { "Authorization" => "Bearer #{result.raw_token}" }, as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it "404 si el token de integración es de otro equipo" do
      owner = create(:membership, :owner)
      other_team = create(:team)
      result = Integration::Create.call(team: owner.team, created_by: owner.user, name: "Bot", scopes: ["read"])

      get "/api/v1/teams/#{other_team.id}/objectives", headers: { "Authorization" => "Bearer #{result.raw_token}" }

      expect(response).to have_http_status(:not_found)
    end
  end
end
