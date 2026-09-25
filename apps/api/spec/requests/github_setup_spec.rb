require "rails_helper"

RSpec.describe "GET /api/v1/github/setup", type: :request do
  around do |example|
    original_app_url = ENV["APP_URL"]
    ENV["APP_URL"] = "http://localhost:3000"
    example.run
    ENV["APP_URL"] = original_app_url
  end

  it "añade installation_id al equipo y redirige a la web" do
    membership = create(:membership)
    state = Github::InstallState.generate(team: membership.team, user: membership.user)

    get "/api/v1/github/setup", params: { installation_id: "777", state: state }

    expect(response).to have_http_status(:found)
    expect(response.location).to eq("http://localhost:3000/t/#{membership.team.id}/settings")
    expect(membership.team.reload.github_installation_ids).to include(777)
  end

  it "vuelve al paso de repo del onboarding si se instaló desde ahí (RF-TEAM-014)" do
    membership = create(:membership)
    state = Github::InstallState.generate(team: membership.team, user: membership.user, return_to: "onboarding")

    get "/api/v1/github/setup", params: { installation_id: "777", state: state }

    expect(response.location).to eq("http://localhost:3000/onboarding?team=#{membership.team.id}&step=repo")
  end

  it "ignora un return_to desconocido" do
    membership = create(:membership)
    state = Github::InstallState.generate(team: membership.team, user: membership.user, return_to: "https://evil.example")

    get "/api/v1/github/setup", params: { installation_id: "777", state: state }

    expect(response.location).to eq("http://localhost:3000/t/#{membership.team.id}/settings")
  end

  it "403 si el usuario del state no es miembro del equipo" do
    team = create(:team)
    outsider = create(:user)
    state = Github::InstallState.generate(team: team, user: outsider)
    # outsider nunca se une al equipo

    get "/api/v1/github/setup", params: { installation_id: "1", state: state }

    expect(response).to have_http_status(:forbidden)
  end

  it "400 con un state inválido" do
    get "/api/v1/github/setup", params: { installation_id: "1", state: "no-es-valido" }

    expect(response).to have_http_status(:bad_request)
  end
end
