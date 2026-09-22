require "rails_helper"

# RF-API-005: Idempotency-Key en los POST.
RSpec.describe "Idempotency-Key", type: :request do
  it "repetir la misma petición con la misma clave devuelve la misma respuesta y no crea dos objetivos" do
    membership = create(:membership)
    token = Pat::Create.call(membership: membership, name: "Agente", preset: "completo").raw_token
    headers = { "Authorization" => "Bearer #{token}", "Idempotency-Key" => "abc-123" }

    post "/api/v1/teams/#{membership.team.id}/objectives", params: { title: "Uno", priority: "must" }, headers: headers, as: :json
    first_body = response.body

    post "/api/v1/teams/#{membership.team.id}/objectives", params: { title: "Uno", priority: "must" }, headers: headers, as: :json

    expect(response.body).to eq(first_body)
    expect(response.headers["Idempotent-Replayed"]).to eq("true")
    expect(Objective.where(team_id: membership.team.id).count).to eq(1)
  end

  it "reutilizar la clave con otro cuerpo da 422 idempotency_key_reused" do
    membership = create(:membership)
    token = Pat::Create.call(membership: membership, name: "Agente", preset: "completo").raw_token
    headers = { "Authorization" => "Bearer #{token}", "Idempotency-Key" => "abc-123" }

    post "/api/v1/teams/#{membership.team.id}/objectives", params: { title: "Uno", priority: "must" }, headers: headers, as: :json
    post "/api/v1/teams/#{membership.team.id}/objectives", params: { title: "Otro", priority: "should" }, headers: headers, as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(json_response["error"]["code"]).to eq("idempotency_key_reused")
  end

  it "sin Idempotency-Key, cada petición crea su propio objetivo" do
    membership = create(:membership)
    token = Pat::Create.call(membership: membership, name: "Agente", preset: "completo").raw_token
    headers = { "Authorization" => "Bearer #{token}" }

    post "/api/v1/teams/#{membership.team.id}/objectives", params: { title: "Uno", priority: "must" }, headers: headers, as: :json
    post "/api/v1/teams/#{membership.team.id}/objectives", params: { title: "Uno", priority: "must" }, headers: headers, as: :json

    expect(Objective.where(team_id: membership.team.id).count).to eq(2)
  end
end
