require "rails_helper"

RSpec.describe "GET /api/v1/cli/config", type: :request do
  it "401 sin token" do
    get "/api/v1/cli/config"

    expect(response).to have_http_status(:unauthorized)
  end

  it "devuelve los repos activos del equipo y las exclusiones por defecto" do
    membership = create(:membership)
    membership.update!(claude_code_attributes: { token_digest: Digest::SHA256.hexdigest("hb_mt_x"), token_prefix: "hb_mt_x", privacy_level: "metadata" })
    create(:repository, team: membership.team, remote_urls: [ "github.com/org/a" ])
    create(:repository, team: membership.team, active: false, remote_urls: [ "github.com/org/inactivo" ])

    get "/api/v1/cli/config", headers: { "Authorization" => "Bearer hb_mt_x" }

    expect(response).to have_http_status(:ok)
    expect(json_response["repos"]).to eq([ "github.com/org/a" ])
    expect(json_response["exclude_globs"]).to include(".env*")
  end

  it "sigue funcionando si el enlace está pausado (hace falta para poder reanudar)" do
    membership = create(:membership)
    membership.update!(claude_code_attributes: { token_digest: Digest::SHA256.hexdigest("hb_mt_x"), token_prefix: "hb_mt_x", privacy_level: "metadata", paused: true })

    get "/api/v1/cli/config", headers: { "Authorization" => "Bearer hb_mt_x" }

    expect(response).to have_http_status(:ok)
  end
end
