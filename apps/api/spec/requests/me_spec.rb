require "rails_helper"

RSpec.describe "PATCH /api/v1/me", type: :request do
  describe "profile_completed (RF-TEAM-014)" do
    it "marks the profile as completed and it cannot be unset" do
      user = create(:user)
      sign_in_as(user)

      get "/api/v1/me"
      expect(json_response["profile_completed"]).to be false

      patch "/api/v1/me", params: { name: "Ada L.", profile_completed: true }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response["profile_completed"]).to be true
      expect(json_response["name"]).to eq("Ada L.")

      patch "/api/v1/me", params: { profile_completed: false }, headers: csrf_headers, as: :json
      expect(json_response["profile_completed"]).to be true
    end
  end

  describe "gemini_api_key (RF-AI-021)" do
    it "sets the personal key and serializes it only as a boolean, never in plain text" do
      user = create(:user)
      sign_in_as(user)

      patch "/api/v1/me", params: { gemini_api_key: "fake-gemini-key" }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response["gemini_api_key_configured"]).to be true
      expect(response.body).not_to include("fake-gemini-key")
      expect(user.reload.gemini_api_key).to eq("fake-gemini-key")
    end

    it "removes the key if it is sent blank" do
      user = create(:user)
      user.update!(gemini_api_key: "fake-gemini-key")
      sign_in_as(user)

      patch "/api/v1/me", params: { gemini_api_key: "" }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response["gemini_api_key_configured"]).to be false
      expect(user.reload.gemini_api_key_configured?).to be false
    end

    it "without the parameter, does not touch the existing key" do
      user = create(:user)
      user.update!(gemini_api_key: "fake-gemini-key")
      sign_in_as(user)

      patch "/api/v1/me", params: { name: "New name" }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(user.reload.gemini_api_key).to eq("fake-gemini-key")
    end
  end
end
