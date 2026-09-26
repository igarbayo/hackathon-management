require "rails_helper"

RSpec.describe "Integration tokens", type: :request do
  describe "POST /api/v1/teams/:team_id/integrations" do
    it "an owner creates an integration" do
      owner = create(:membership, :owner)
      sign_in_as(owner.user)

      post "/api/v1/teams/#{owner.team.id}/integrations", params: { name: "Slack bot", scopes: [ "features:write" ] }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response["token"]).to start_with("hb_it_")
    end

    it "a regular member cannot create integrations" do
      member = create(:membership)
      sign_in_as(member.user)

      post "/api/v1/teams/#{member.team.id}/integrations", params: { name: "Bot" }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it "session_only: a token cannot create integrations" do
      owner = create(:membership, :owner)
      token = Pat::Create.call(membership: owner, name: "Completo", preset: "full").raw_token

      post "/api/v1/teams/#{owner.team.id}/integrations", params: { name: "Bot" }, headers: { "Authorization" => "Bearer #{token}" }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(json_response["error"]["code"]).to eq("session_required")
    end
  end

  describe "DELETE /api/v1/teams/:team_id/integrations/:id" do
    it "an owner can revoke it" do
      owner = create(:membership, :owner)
      integration = create(:access_token, :integration, team: owner.team, created_by_id: owner.user_id)
      sign_in_as(owner.user)

      delete "/api/v1/teams/#{owner.team.id}/integrations/#{integration.id}", headers: csrf_headers

      expect(response).to have_http_status(:no_content)
      expect(integration.reload.revoked_at).to be_present
    end
  end

  describe "POST /api/v1/teams/:team_id/integrations/:id/rotate" do
    it "an owner rotates the token without changing its name or scopes (RF-API-023)" do
      owner = create(:membership, :owner)
      integration = create(:access_token, :integration, team: owner.team, created_by_id: owner.user_id, scopes: [ "read", "features:write" ])
      old_digest = integration.token_digest
      sign_in_as(owner.user)

      post "/api/v1/teams/#{owner.team.id}/integrations/#{integration.id}/rotate", headers: csrf_headers

      expect(response).to have_http_status(:ok)
      expect(json_response["token"]).to start_with("hb_it_")
      integration.reload
      expect(integration.token_digest).not_to eq(old_digest)
      expect(integration.scopes).to contain_exactly("read", "features:write")
    end

    it "a regular member cannot rotate it" do
      owner = create(:membership, :owner)
      integration = create(:access_token, :integration, team: owner.team, created_by_id: owner.user_id)
      member = create(:membership, team: owner.team)
      sign_in_as(member.user)

      post "/api/v1/teams/#{owner.team.id}/integrations/#{integration.id}/rotate", headers: csrf_headers

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "using an integration token on the domain API" do
    it "creates a feature with the integration as the actor, with no person" do
      owner = create(:membership, :owner)
      result = Integration::Create.call(team: owner.team, created_by: owner.user, name: "Bot", scopes: [ "features:write" ])

      post "/api/v1/teams/#{owner.team.id}/features", params: { title: "Made by the bot" }, headers: { "Authorization" => "Bearer #{result.raw_token}" }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response["created_by_id"]).to be_nil

      event = ActivityEvent.where(team_id: owner.team.id, kind: "feature_created").first
      expect(event.actor["integration_id"]).to eq(result.record.id.to_s)
      expect(event.via["token_kind"]).to eq("integration")
    end

    it "cannot vote or add arguments (an action of a person)" do
      owner = create(:membership, :owner)
      feature = create(:feature, team: owner.team)
      result = Integration::Create.call(team: owner.team, created_by: owner.user, name: "Bot", scopes: [ "arguments:write" ])

      post "/api/v1/teams/#{owner.team.id}/features/#{feature.key}/arguments", params: { kind: "pro", text: "..." },
                                                                                headers: { "Authorization" => "Bearer #{result.raw_token}" }, as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it "404 if the integration token belongs to another team" do
      owner = create(:membership, :owner)
      other_team = create(:team)
      result = Integration::Create.call(team: owner.team, created_by: owner.user, name: "Bot", scopes: [ "read" ])

      get "/api/v1/teams/#{other_team.id}/objectives", headers: { "Authorization" => "Bearer #{result.raw_token}" }

      expect(response).to have_http_status(:not_found)
    end
  end
end
