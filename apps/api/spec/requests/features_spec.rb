require "rails_helper"

RSpec.describe "Features", type: :request do
  describe "POST /api/v1/teams/:team_id/features" do
    it "creates the feature with an atomic key" do
      membership = create(:membership)
      sign_in_as(membership.user)

      post "/api/v1/teams/#{membership.team.id}/features", params: { title: "Login" }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response["key"]).to eq("F-1")
      expect(json_response["status"]).to eq("idea")
    end
  end

  describe "GET /api/v1/teams/:team_id/features/:key" do
    it "finds by F-n key" do
      membership = create(:membership)
      feature = create(:feature, team: membership.team)
      sign_in_as(membership.user)

      get "/api/v1/teams/#{membership.team.id}/features/#{feature.key}"

      expect(response).to have_http_status(:ok)
      expect(json_response["id"]).to eq(feature.id.to_s)
    end

    it "includes the branches of its GitHub activity (RF-GH-026)" do
      membership = create(:membership)
      feature = create(:feature, team: membership.team, branch_names: %w[f-1-login])
      event = create(:activity_event, :github_commit, team: membership.team, branch: "f-1-api", branches: %w[f-1-api main])
      event.build_attribution(feature_id: feature.id, method: "manual", status: "confirmed")
      event.save!
      create(:activity_event, :github_commit, team: membership.team, branch: "other", branches: %w[other])
      sign_in_as(membership.user)

      get "/api/v1/teams/#{membership.team.id}/features/#{feature.key}"

      expect(json_response["activity_branches"]).to eq(%w[f-1-api f-1-login main])
    end

    it "finds by id" do
      membership = create(:membership)
      feature = create(:feature, team: membership.team)
      sign_in_as(membership.user)

      get "/api/v1/teams/#{membership.team.id}/features/#{feature.id}"

      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /api/v1/teams/:team_id/features/:key" do
    it "creates a system event when the status changes" do
      membership = create(:membership)
      feature = create(:feature, team: membership.team, status: "idea")
      sign_in_as(membership.user)

      patch "/api/v1/teams/#{membership.team.id}/features/#{feature.key}",
            params: { status: "in_progress" }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:ok)
      event = ActivityEvent.where(team_id: membership.team.id, kind: "feature_status_changed").first
      expect(event).to be_present
      expect(event.payload["key"]).to eq(feature.key)
    end

    it "returns 409 with an outdated If-Match" do
      membership = create(:membership)
      feature = create(:feature, team: membership.team)
      sign_in_as(membership.user)

      patch "/api/v1/teams/#{membership.team.id}/features/#{feature.key}",
            params: { title: "Another title" },
            headers: csrf_headers.merge("If-Match" => 1.hour.ago.iso8601(3)), as: :json

      expect(response).to have_http_status(:conflict)
    end

    it "accepts the update with the right If-Match" do
      membership = create(:membership)
      feature = create(:feature, team: membership.team)
      sign_in_as(membership.user)

      patch "/api/v1/teams/#{membership.team.id}/features/#{feature.key}",
            params: { title: "Another title" },
            headers: csrf_headers.merge("If-Match" => feature.updated_at.iso8601(3)), as: :json

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /api/v1/teams/:team_id/features/:key/move" do
    it "works out the position between the neighbors in the target column" do
      membership = create(:membership)
      team = membership.team
      card_a = create(:feature, team: team, status: "in_progress", position: 1.0)
      card_b = create(:feature, team: team, status: "in_progress", position: 2.0)
      moved = create(:feature, team: team, status: "idea", position: 0.0)
      sign_in_as(membership.user)

      post "/api/v1/teams/#{team.id}/features/#{moved.key}/move",
           params: { status: "in_progress", after_id: card_a.id.to_s, before_id: card_b.id.to_s },
           headers: csrf_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(moved.reload.status).to eq("in_progress")
      expect(moved.position).to eq(1.5)
    end
  end

  describe "DELETE /api/v1/teams/:team_id/features/:key" do
    it "does not let a feature with attributed events be deleted" do
      membership = create(:membership)
      feature = create(:feature, team: membership.team)
      ActivityEvent.create!(
        team_id: membership.team.id, source: "system", kind: "member_joined",
        dedupe_key: "x", occurred_at: Time.current
      ).tap { |e| e.build_attribution(feature_id: feature.id, method: "manual", status: "confirmed"); e.save! }
      sign_in_as(membership.user)

      delete "/api/v1/teams/#{membership.team.id}/features/#{feature.key}", headers: csrf_headers

      expect(response).to have_http_status(:conflict)
    end

    it "deletes a feature with no events" do
      membership = create(:membership)
      feature = create(:feature, team: membership.team)
      sign_in_as(membership.user)

      delete "/api/v1/teams/#{membership.team.id}/features/#{feature.key}", headers: csrf_headers

      expect(response).to have_http_status(:no_content)
    end
  end
end
