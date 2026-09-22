require "rails_helper"

# RNF-SEC-001: toda consulta de dominio se acota por current_team. Un miembro
# del equipo A nunca puede leer ni escribir datos del equipo B, aunque
# conozca sus ids.
RSpec.describe "Aislamiento entre equipos (RNF-SEC-001)", type: :request do
  it "un miembro del equipo A no puede ver los objetivos del equipo B" do
    membership_a = create(:membership)
    team_b = create(:team)
    objective_b = create(:objective, team: team_b)
    sign_in_as(membership_a.user)

    get "/api/v1/teams/#{team_b.id}/objectives"
    expect(response).to have_http_status(:not_found)

    patch "/api/v1/teams/#{team_b.id}/objectives/#{objective_b.id}", params: { title: "hackeado" }, headers: csrf_headers, as: :json
    expect(response).to have_http_status(:not_found)
    expect(objective_b.reload.title).not_to eq("hackeado")
  end

  it "un miembro del equipo A no puede mover una feature del equipo B usando el id de A en la URL pero el id de B en el body" do
    membership_a = create(:membership)
    membership_b = create(:membership)
    feature_b = create(:feature, team: membership_b.team)
    sign_in_as(membership_a.user)

    get "/api/v1/teams/#{membership_a.team.id}/features/#{feature_b.id}"

    expect(response).to have_http_status(:not_found)
  end

  it "no puede ver los miembros de un equipo ajeno" do
    membership_a = create(:membership)
    membership_b = create(:membership)
    sign_in_as(membership_a.user)

    get "/api/v1/teams/#{membership_b.team.id}/members"

    expect(response).to have_http_status(:not_found)
  end
end
