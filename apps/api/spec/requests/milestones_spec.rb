require "rails_helper"

RSpec.describe "Milestones & timeline", type: :request do
  describe "CRUD /api/v1/teams/:team_id/milestones" do
    it "cualquier miembro puede crear uno" do
      membership = create(:membership)
      sign_in_as(membership.user)

      post "/api/v1/teams/#{membership.team.id}/milestones",
           params: { title: "Demo", kind: "demo", due_at: 2.days.from_now }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:created)
    end

    it "los lista ordenados por due_at" do
      membership = create(:membership)
      create(:milestone, team: membership.team, due_at: 3.days.from_now, title: "Tarde")
      create(:milestone, team: membership.team, due_at: 1.day.from_now, title: "Pronto")
      sign_in_as(membership.user)

      get "/api/v1/teams/#{membership.team.id}/milestones"

      expect(json_response["data"].map { |m| m["title"] }).to eq(%w[Pronto Tarde])
    end
  end

  describe "GET /api/v1/teams/:team_id/timeline" do
    it "marca overdue las features con deadline pasado y no done" do
      membership = create(:membership)
      create(:feature, team: membership.team, title: "Vencida", deadline: 1.day.ago, status: "in_progress")
      create(:feature, team: membership.team, title: "Hecha aunque vencida", deadline: 1.day.ago, status: "done")
      sign_in_as(membership.user)

      get "/api/v1/teams/#{membership.team.id}/timeline"

      overdue = json_response["data"].find { |i| i["title"] == "Vencida" }
      not_overdue = json_response["data"].find { |i| i["title"] == "Hecha aunque vencida" }
      expect(overdue["overdue"]).to be true
      expect(not_overdue["overdue"]).to be false
    end
  end
end
