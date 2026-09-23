require "rails_helper"

RSpec.describe "PATCH /api/v1/me", type: :request do
  describe "gemini_api_key (RF-AI-021)" do
    it "pone la clave personal y la serializa solo como booleano, nunca en claro" do
      user = create(:user)
      sign_in_as(user)

      patch "/api/v1/me", params: { gemini_api_key: "fake-gemini-key" }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response["gemini_api_key_configured"]).to be true
      expect(response.body).not_to include("fake-gemini-key")
      expect(user.reload.gemini_api_key).to eq("fake-gemini-key")
    end

    it "quita la clave si se manda en blanco" do
      user = create(:user)
      user.update!(gemini_api_key: "fake-gemini-key")
      sign_in_as(user)

      patch "/api/v1/me", params: { gemini_api_key: "" }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response["gemini_api_key_configured"]).to be false
      expect(user.reload.gemini_api_key_configured?).to be false
    end

    it "sin el parámetro, no toca la clave existente" do
      user = create(:user)
      user.update!(gemini_api_key: "fake-gemini-key")
      sign_in_as(user)

      patch "/api/v1/me", params: { name: "Nuevo nombre" }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(user.reload.gemini_api_key).to eq("fake-gemini-key")
    end
  end
end
