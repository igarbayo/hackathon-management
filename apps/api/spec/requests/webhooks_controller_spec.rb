require "rails_helper"

RSpec.describe "Webhooks salientes", type: :request do
  describe "POST /api/v1/teams/:team_id/webhooks" do
    it "un owner crea un webhook y ve el secreto una sola vez" do
      owner = create(:membership, :owner)
      sign_in_as(owner.user)

      post "/api/v1/teams/#{owner.team.id}/webhooks", params: { url: "https://example.com/hook", events: [ "feature.created" ] },
                                                        headers: csrf_headers, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response["secret"]).to be_present
      expect(json_response["events"]).to eq([ "feature.created" ])
    end

    it "un miembro normal no puede crear webhooks" do
      member = create(:membership)
      sign_in_as(member.user)

      post "/api/v1/teams/#{member.team.id}/webhooks", params: { url: "https://example.com/hook", events: [ "ping" ] }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it "session_only: ningún token puede gestionar webhooks" do
      owner = create(:membership, :owner)
      token = Pat::Create.call(membership: owner, name: "Completo", preset: "completo").raw_token

      get "/api/v1/teams/#{owner.team.id}/webhooks", headers: { "Authorization" => "Bearer #{token}" }

      expect(response).to have_http_status(:forbidden)
      expect(json_response["error"]["code"]).to eq("session_required")
    end

    it "rechaza URLs que no sean HTTPS" do
      owner = create(:membership, :owner)
      sign_in_as(owner.user)

      post "/api/v1/teams/#{owner.team.id}/webhooks", params: { url: "http://example.com/hook", events: [ "ping" ] }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "POST /api/v1/teams/:team_id/webhooks/:id/rotate_secret" do
    it "rota el secreto y lo devuelve una sola vez" do
      owner = create(:membership, :owner)
      webhook = create(:outbound_webhook, team: owner.team, secret: "viejo")
      sign_in_as(owner.user)

      post "/api/v1/teams/#{owner.team.id}/webhooks/#{webhook.id}/rotate_secret", headers: csrf_headers

      expect(response).to have_http_status(:ok)
      expect(json_response["secret"]).not_to eq("viejo")
      expect(webhook.reload.secret).to eq(json_response["secret"])
    end
  end

  describe "POST /api/v1/teams/:team_id/webhooks/:id/test" do
    it "encola un ping" do
      owner = create(:membership, :owner)
      webhook = create(:outbound_webhook, team: owner.team, events: [ "ping" ])
      sign_in_as(owner.user)

      post "/api/v1/teams/#{owner.team.id}/webhooks/#{webhook.id}/test", headers: csrf_headers

      expect(response).to have_http_status(:accepted)
      expect(Webhooks::DeliverJob.jobs.size).to eq(1)
    end
  end

  describe "GET .../deliveries y POST .../deliveries/:id/redeliver" do
    it "lista las entregas y permite reenviar una" do
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

  describe "creación con un objetivo real dispara el webhook (integración end-to-end sin red)" do
    it "objective.created llega a Webhooks::Enqueue" do
      owner = create(:membership, :owner)
      create(:outbound_webhook, team: owner.team, events: [ "objective.created" ])
      sign_in_as(owner.user)

      post "/api/v1/teams/#{owner.team.id}/objectives", params: { title: "Nuevo", priority: "must" }, headers: csrf_headers, as: :json

      expect(Webhooks::DeliverJob.jobs.size).to eq(1)
    end
  end
end
