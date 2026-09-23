require "rails_helper"

RSpec.describe "Analyses", type: :request do
  describe "POST /api/v1/teams/:team_id/analyses" do
    it "encola un análisis manual y devuelve su id" do
      membership = create(:membership)
      membership.user.update!(gemini_api_key: "test-key")
      sign_in_as(membership.user)

      post "/api/v1/teams/#{membership.team.id}/analyses", headers: csrf_headers

      expect(response).to have_http_status(:accepted)
      expect(json_response["status"]).to eq("queued")
      expect(AiAnalysis.where(id: json_response["id"]).first).to be_present
    end

    it "responde 422 si no tengo una clave de Gemini configurada" do
      membership = create(:membership)
      sign_in_as(membership.user)

      post "/api/v1/teams/#{membership.team.id}/analyses", headers: csrf_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response["error"]["code"]).to eq("missing_gemini_api_key")
    end

    it "responde 429 al superar la cuota manual diaria del plan" do
      membership = create(:membership)
      membership.user.update!(gemini_api_key: "test-key")
      5.times { create(:ai_analysis, team: membership.team, trigger: "manual") }
      sign_in_as(membership.user)

      post "/api/v1/teams/#{membership.team.id}/analyses", headers: csrf_headers

      expect(response).to have_http_status(:too_many_requests)
      expect(response.headers["Retry-After"]).to be_present
    end
  end

  describe "GET /api/v1/teams/:team_id/analyses" do
    it "no incluye el result completo en el historial" do
      membership = create(:membership)
      create(:ai_analysis, team: membership.team, status: "succeeded", result: { "summary" => "x" })
      sign_in_as(membership.user)

      get "/api/v1/teams/#{membership.team.id}/analyses"

      expect(json_response["data"].first).not_to have_key("result")
    end
  end

  describe "GET /api/v1/teams/:team_id/analyses/latest" do
    it "devuelve el último succeeded con las alertas deterministas calculadas ahora" do
      membership = create(:membership)
      old = create(:ai_analysis, team: membership.team, status: "succeeded", result: { "summary" => "antiguo" }, created_at: 1.hour.ago)
      create(:ai_analysis, team: membership.team, status: "failed", created_at: 5.minutes.ago)
      sign_in_as(membership.user)

      get "/api/v1/teams/#{membership.team.id}/analyses/latest"

      expect(response).to have_http_status(:ok)
      expect(json_response["analysis"]["id"]).to eq(old.id.to_s)
      expect(json_response["deterministic_alerts"]).to be_an(Array)
    end

    it "devuelve analysis nil si nunca hubo uno succeeded" do
      membership = create(:membership)
      sign_in_as(membership.user)

      get "/api/v1/teams/#{membership.team.id}/analyses/latest"

      expect(json_response["analysis"]).to be_nil
      expect(json_response["deterministic_alerts"]).to be_an(Array)
    end
  end

  describe "GET /api/v1/teams/:team_id/analyses/:id" do
    it "aísla por equipo" do
      other_team_analysis = create(:ai_analysis)
      membership = create(:membership)
      sign_in_as(membership.user)

      get "/api/v1/teams/#{membership.team.id}/analyses/#{other_team_analysis.id}"

      expect(response).to have_http_status(:not_found)
    end
  end
end
