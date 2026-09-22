require "rails_helper"

RSpec.describe "Objectives", type: :request do
  describe "POST /api/v1/teams/:team_id/objectives" do
    it "crea el objetivo con key atómica" do
      membership = create(:membership)
      sign_in_as(membership.user)

      post "/api/v1/teams/#{membership.team.id}/objectives",
           params: { title: "Reducir latencia", priority: "must" },
           headers: csrf_headers, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response["key"]).to eq("O-1")
    end
  end

  describe "GET /api/v1/teams/:team_id/objectives" do
    it "incluye feature_count por estado" do
      membership = create(:membership)
      objective = create(:objective, team: membership.team)
      create(:feature, team: membership.team, status: "idea", objective_ids: [objective.id])
      create(:feature, team: membership.team, status: "done", objective_ids: [objective.id])
      sign_in_as(membership.user)

      get "/api/v1/teams/#{membership.team.id}/objectives"

      counts = json_response["data"].first["feature_count"]
      expect(counts["idea"]).to eq(1)
      expect(counts["done"]).to eq(1)
    end
  end

  describe "PATCH /api/v1/teams/:team_id/objectives/:id" do
    it "archiva el objetivo" do
      membership = create(:membership)
      objective = create(:objective, team: membership.team)
      sign_in_as(membership.user)

      patch "/api/v1/teams/#{membership.team.id}/objectives/#{objective.id}",
            params: { archived: true }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response["archived"]).to be true
    end
  end

  describe "DELETE /api/v1/teams/:team_id/objectives/:id" do
    it "borra el objetivo y lo quita de feature.objective_ids" do
      membership = create(:membership)
      objective = create(:objective, team: membership.team)
      feature = create(:feature, team: membership.team, objective_ids: [objective.id])
      sign_in_as(membership.user)

      delete "/api/v1/teams/#{membership.team.id}/objectives/#{objective.id}", headers: csrf_headers

      expect(response).to have_http_status(:no_content)
      expect(feature.reload.objective_ids).to be_empty
    end
  end
end
