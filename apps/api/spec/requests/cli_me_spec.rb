require "rails_helper"

RSpec.describe "PATCH/DELETE /api/v1/cli/me", type: :request do
  let(:membership) { create(:membership) }
  let(:raw_token) { "hb_mt_meself" }

  before do
    membership.update!(claude_code_attributes: { token_digest: Digest::SHA256.hexdigest(raw_token), token_prefix: raw_token[0, 12], privacy_level: "metadata" })
  end

  it "401 sin Authorization" do
    patch "/api/v1/cli/me", params: { paused: true }, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it "reanuda un enlace pausado con el mismo token (sin CSRF, no hay cookie)" do
    membership.claude_code.update!(paused: true)

    patch "/api/v1/cli/me", params: { paused: false }, headers: { "Authorization" => "Bearer #{raw_token}" }, as: :json

    expect(response).to have_http_status(:ok)
    expect(membership.reload.claude_code.paused).to be false
  end

  it "cambia el nivel de privacidad" do
    patch "/api/v1/cli/me", params: { privacy_level: "summaries" }, headers: { "Authorization" => "Bearer #{raw_token}" }, as: :json

    expect(response).to have_http_status(:ok)
    expect(membership.reload.claude_code.privacy_level).to eq("summaries")
  end

  it "hackboard uninstall: DELETE revoca el token" do
    delete "/api/v1/cli/me", headers: { "Authorization" => "Bearer #{raw_token}" }

    expect(response).to have_http_status(:no_content)
    expect(membership.reload.claude_code).to be_nil
  end

  it "DELETE ?purge=true borra también los eventos propios" do
    event = create(:activity_event, :claude_turn, team: membership.team, actor: { "membership_id" => membership.id.to_s })

    delete "/api/v1/cli/me?purge=true", headers: { "Authorization" => "Bearer #{raw_token}" }

    expect(response).to have_http_status(:no_content)
    expect(ActivityEvent.where(id: event.id).first).to be_nil
  end
end
