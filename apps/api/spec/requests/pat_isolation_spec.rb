require "rails_helper"

# RNF-API-002: un PAT se comporta como cualquier otro canal frente al
# aislamiento entre equipos y los scopes.
RSpec.describe "Aislamiento y scopes con PAT (RNF-API-002)", type: :request do
  it "404 si el token es de otro equipo, aunque tenga todos los scopes" do
    membership_a = create(:membership)
    team_b = create(:team)
    objective_b = create(:objective, team: team_b)
    result = Pat::Create.call(membership: membership_a, name: "Completo", preset: "completo")

    get "/api/v1/teams/#{team_b.id}/objectives", headers: { "Authorization" => "Bearer #{result.raw_token}" }
    expect(response).to have_http_status(:not_found)

    patch "/api/v1/teams/#{team_b.id}/objectives/#{objective_b.id}", params: { title: "hackeado" },
                                                                       headers: { "Authorization" => "Bearer #{result.raw_token}" }, as: :json
    expect(response).to have_http_status(:not_found)
    expect(objective_b.reload.title).not_to eq("hackeado")
  end

  it "403 insufficient_scope si al token le falta el scope, aunque sea del equipo correcto" do
    membership = create(:membership)
    result = Pat::Create.call(membership: membership, name: "Solo lectura", preset: "observar")

    post "/api/v1/teams/#{membership.team.id}/objectives", params: { title: "Nuevo objetivo" },
                                                             headers: { "Authorization" => "Bearer #{result.raw_token}" }, as: :json

    expect(response).to have_http_status(:forbidden)
    expect(json_response["error"]["code"]).to eq("insufficient_scope")
    expect(json_response["error"]["details"]["required_scope"]).to eq("objectives:write")
  end

  it "200 si el token es del equipo correcto y tiene el scope" do
    membership = create(:membership)
    result = Pat::Create.call(membership: membership, name: "Agente", preset: "agente")

    post "/api/v1/teams/#{membership.team.id}/features", params: { title: "Nueva feature" },
                                                           headers: { "Authorization" => "Bearer #{result.raw_token}" }, as: :json

    expect(response).to have_http_status(:created)
  end

  it "ningún endpoint session_only acepta Bearer, ni siquiera con todos los scopes" do
    membership = create(:membership)
    feature = create(:feature, team: membership.team)
    result = Pat::Create.call(membership: membership, name: "Completo", preset: "completo")

    delete "/api/v1/teams/#{membership.team.id}/features/#{feature.key}", headers: { "Authorization" => "Bearer #{result.raw_token}" }

    expect(response).to have_http_status(:forbidden)
    expect(json_response["error"]["code"]).to eq("session_required")
  end

  it "400 si la petición trae cookie de sesión y Bearer a la vez" do
    membership = create(:membership)
    result = Pat::Create.call(membership: membership, name: "Token", preset: "observar")
    sign_in_as(membership.user)

    get "/api/v1/teams/#{membership.team.id}/objectives", headers: { "Authorization" => "Bearer #{result.raw_token}" }

    expect(response).to have_http_status(:bad_request)
  end

  it "401 si el token está revocado" do
    membership = create(:membership)
    result = Pat::Create.call(membership: membership, name: "Token", preset: "completo")
    result.record.update!(revoked_at: Time.current, revoke_reason: "manual")

    get "/api/v1/teams/#{membership.team.id}/objectives", headers: { "Authorization" => "Bearer #{result.raw_token}" }

    expect(response).to have_http_status(:unauthorized)
  end

  it "429 al superar el límite de escrituras por minuto (RNF-API-001)" do
    membership = create(:membership)
    result = Pat::Create.call(membership: membership, name: "Agente", preset: "agente")
    headers = { "Authorization" => "Bearer #{result.raw_token}" }

    30.times { post "/api/v1/teams/#{membership.team.id}/features", params: { title: "F" }, headers: headers, as: :json }
    post "/api/v1/teams/#{membership.team.id}/features", params: { title: "F" }, headers: headers, as: :json

    expect(response).to have_http_status(:too_many_requests)
  end
end
