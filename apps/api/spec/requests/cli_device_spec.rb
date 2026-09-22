require "rails_helper"

RSpec.describe "Device flow del CLI", type: :request do
  describe "POST /api/v1/cli/device" do
    it "crea un device_code y un user_code sin necesitar sesión" do
      post "/api/v1/cli/device"

      expect(response).to have_http_status(:created)
      expect(json_response["device_code"]).to be_present
      expect(json_response["user_code"]).to match(/\A[A-Z0-9]{4}-[A-Z0-9]{4}\z/)
      expect(json_response["verification_url"]).to include(json_response["user_code"])
    end
  end

  describe "POST /api/v1/teams/:team_id/cli/device/approve" do
    it "requiere sesión" do
      membership = create(:membership)

      post "/api/v1/teams/#{membership.team.id}/cli/device/approve", params: { user_code: "AAAA-BBBB", privacy_level: "metadata" }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it "aprueba el código y deja el device_authorization listo para canjear" do
      membership = create(:membership)
      record = create(:device_authorization)
      sign_in_as(membership.user)

      post "/api/v1/teams/#{membership.team.id}/cli/device/approve",
        params: { user_code: record.user_code, privacy_level: "summaries" }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:no_content)
      expect(record.reload.status).to eq("approved")
      expect(record.membership_id).to eq(membership.id)
    end

    it "exige CSRF" do
      membership = create(:membership)
      record = create(:device_authorization)
      sign_in_as(membership.user)

      post "/api/v1/teams/#{membership.team.id}/cli/device/approve", params: { user_code: record.user_code, privacy_level: "metadata" }, as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /api/v1/teams/:team_id/cli/device/deny" do
    it "rechaza el código" do
      membership = create(:membership)
      record = create(:device_authorization)
      sign_in_as(membership.user)

      post "/api/v1/teams/#{membership.team.id}/cli/device/deny", params: { user_code: record.user_code }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:no_content)
      expect(record.reload.status).to eq("denied")
    end
  end

  describe "POST /api/v1/cli/device/token" do
    it "authorization_pending sin sesión ni CSRF mientras no se apruebe" do
      post "/api/v1/cli/device"
      device_code = json_response["device_code"]

      post "/api/v1/cli/device/token", params: { device_code: device_code }, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(json_response["error"]).to eq("authorization_pending")
    end

    it "devuelve el token hb_mt_ tras aprobar" do
      membership = create(:membership)
      post "/api/v1/cli/device"
      device_code = json_response["device_code"]
      user_code = json_response["user_code"]
      sign_in_as(membership.user)
      post "/api/v1/teams/#{membership.team.id}/cli/device/approve", params: { user_code: user_code, privacy_level: "metadata" }, headers: csrf_headers, as: :json

      post "/api/v1/cli/device/token", params: { device_code: device_code }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response["token"]).to start_with("hb_mt_")
      expect(json_response["team"]["id"]).to eq(membership.team.id.to_s)
    end
  end
end
