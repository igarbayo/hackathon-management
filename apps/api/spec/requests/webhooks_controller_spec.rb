require "rails_helper"

RSpec.describe "Outgoing webhooks", type: :request do
  describe "POST /api/v1/teams/:team_id/webhooks" do
    it "an owner creates a webhook and sees the secret only once" do
      owner = create(:membership, :owner)
      sign_in_as(owner.user)

      post "/api/v1/teams/#{owner.team.id}/webhooks", params: { url: "https://example.com/hook", events: [ "feature.created" ] },
                                                        headers: csrf_headers, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response["secret"]).to be_present
      expect(json_response["events"]).to eq([ "feature.created" ])
    end

    it "a regular member cannot create webhooks" do
      member = create(:membership)
      sign_in_as(member.user)

      post "/api/v1/teams/#{member.team.id}/webhooks", params: { url: "https://example.com/hook", events: [ "ping" ] }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it "session_only: no token can manage webhooks" do
      owner = create(:membership, :owner)
      token = Pat::Create.call(membership: owner, name: "Completo", preset: "full").raw_token

      get "/api/v1/teams/#{owner.team.id}/webhooks", headers: { "Authorization" => "Bearer #{token}" }

      expect(response).to have_http_status(:forbidden)
      expect(json_response["error"]["code"]).to eq("session_required")
    end

    it "rejects URLs that are not HTTPS" do
      owner = create(:membership, :owner)
      sign_in_as(owner.user)

      post "/api/v1/teams/#{owner.team.id}/webhooks", params: { url: "http://example.com/hook", events: [ "ping" ] }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "POST /api/v1/teams/:team_id/webhooks/:id/rotate_secret" do
    it "rotates the secret and returns it only once" do
      owner = create(:membership, :owner)
      webhook = create(:outbound_webhook, team: owner.team, secret: "old")
      sign_in_as(owner.user)

      post "/api/v1/teams/#{owner.team.id}/webhooks/#{webhook.id}/rotate_secret", headers: csrf_headers

      expect(response).to have_http_status(:ok)
      expect(json_response["secret"]).not_to eq("old")
      expect(webhook.reload.secret).to eq(json_response["secret"])
    end
  end

  describe "POST /api/v1/teams/:team_id/webhooks/:id/test" do
    it "queues a ping" do
      owner = create(:membership, :owner)
      webhook = create(:outbound_webhook, team: owner.team, events: [ "ping" ])
      sign_in_as(owner.user)

      post "/api/v1/teams/#{owner.team.id}/webhooks/#{webhook.id}/test", headers: csrf_headers

      expect(response).to have_http_status(:accepted)
      expect(Webhooks::DeliverJob.jobs.size).to eq(1)
    end
  end

  describe "GET .../deliveries and POST .../deliveries/:id/redeliver" do
    it "lists the deliveries and lets you redeliver one" do
      owner = create(:membership, :owner)
      webhook = create(:outbound_webhook, team: owner.team)
      delivery = create(:outbound_delivery, team: owner.team, outbound_webhook: webhook, status: "failed", payload: { "event" => "ping" })
      sign_in_as(owner.user)

      get "/api/v1/teams/#{owner.team.id}/webhooks/#{webhook.id}/deliveries"
      expect(json_response["data"].map { |d| d["id"] }).to eq([ delivery.id.to_s ])

      post "/api/v1/teams/#{owner.team.id}/webhooks/#{webhook.id}/deliveries/#{delivery.id}/redeliver", headers: csrf_headers
      expect(response).to have_http_status(:accepted)
      expect(Webhooks::DeliverJob.jobs.size).to eq(1)
    end
  end

  describe "creating a real objective fires the webhook (end-to-end integration with no network)" do
    it "objective.created reaches Webhooks::Enqueue" do
      owner = create(:membership, :owner)
      create(:outbound_webhook, team: owner.team, events: [ "objective.created" ])
      sign_in_as(owner.user)

      post "/api/v1/teams/#{owner.team.id}/objectives", params: { title: "New", priority: "must" }, headers: csrf_headers, as: :json

      expect(Webhooks::DeliverJob.jobs.size).to eq(1)
    end
  end
end
