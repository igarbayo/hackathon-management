require "rails_helper"

RSpec.describe "Activity", type: :request do
  describe "GET /api/v1/teams/:team_id/activity" do
    it "pagina por cursor, más reciente primero" do
      membership = create(:membership)
      3.times { |n| create(:activity_event, :github_commit, team: membership.team, occurred_at: n.hours.ago) }
      sign_in_as(membership.user)

      get "/api/v1/teams/#{membership.team.id}/activity", params: { limit: 2 }

      expect(response).to have_http_status(:ok)
      expect(json_response["data"].size).to eq(2)
      expect(json_response["next_cursor"]).to be_present

      get "/api/v1/teams/#{membership.team.id}/activity", params: { limit: 2, cursor: json_response["next_cursor"] }
      expect(json_response["data"].size).to eq(1)
      expect(json_response["next_cursor"]).to be_nil
    end

    it "filtra por attribution_status=none" do
      membership = create(:membership)
      feature = create(:feature, team: membership.team)
      attributed = create(:activity_event, :github_commit, team: membership.team)
      attributed.build_attribution(feature_id: feature.id, method: "manual", status: "confirmed")
      attributed.save!
      unattributed = create(:activity_event, :github_commit, team: membership.team)
      sign_in_as(membership.user)

      get "/api/v1/teams/#{membership.team.id}/activity", params: { attribution_status: "none" }

      ids = json_response["data"].map { |e| e["id"] }
      expect(ids).to contain_exactly(unattributed.id.to_s)
    end

    it "aísla por equipo (RNF-SEC-001)" do
      membership = create(:membership)
      other_team = create(:team)
      create(:activity_event, :github_commit, team: other_team)
      sign_in_as(membership.user)

      get "/api/v1/teams/#{other_team.id}/activity"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/teams/:team_id/activity/summary" do
    it "cuenta eventos por persona en la ventana" do
      membership = create(:membership)
      create(:activity_event, :github_commit, team: membership.team, actor: { "user_id" => membership.user.id.to_s })
      create(:activity_event, :github_commit, team: membership.team, occurred_at: 2.days.ago)
      sign_in_as(membership.user)

      get "/api/v1/teams/#{membership.team.id}/activity/summary", params: { window: "24h" }

      expect(json_response["total"]).to eq(1)
    end
  end

  describe "POST /api/v1/teams/:team_id/activity/:event_id/attribution" do
    it "confirma una sugerencia" do
      membership = create(:membership)
      feature = create(:feature, team: membership.team)
      event = create(:activity_event, :github_commit, team: membership.team)
      event.build_attribution(feature_id: feature.id, method: "ai", status: "suggested", confidence: 0.6)
      event.save!
      sign_in_as(membership.user)

      post "/api/v1/teams/#{membership.team.id}/activity/#{event.id}/attribution",
           params: { action: "confirm" }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response["attribution"]["status"]).to eq("confirmed")
    end

    it "asigna con set y feature_id" do
      membership = create(:membership)
      feature = create(:feature, team: membership.team)
      event = create(:activity_event, :github_commit, team: membership.team)
      sign_in_as(membership.user)

      post "/api/v1/teams/#{membership.team.id}/activity/#{event.id}/attribution",
           params: { action: "set", feature_id: feature.id.to_s }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response["attribution"]["method"]).to eq("manual")
      expect(json_response["attribution"]["feature_id"]).to eq(feature.id.to_s)
    end
  end

  describe "POST /api/v1/teams/:team_id/activity/attribution/bulk" do
    it "aplica la acción a varios eventos a la vez" do
      membership = create(:membership)
      feature = create(:feature, team: membership.team)
      events = Array.new(3) { create(:activity_event, :github_commit, team: membership.team) }
      sign_in_as(membership.user)

      post "/api/v1/teams/#{membership.team.id}/activity/attribution/bulk",
           params: { event_ids: events.map { |e| e.id.to_s }, action: "set", feature_id: feature.id.to_s },
           headers: csrf_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response["data"].size).to eq(3)
      expect(events.map(&:reload).map { |e| e.attribution.feature_id }).to all(eq(feature.id))
    end
  end
end
