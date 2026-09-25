require "rails_helper"

RSpec.describe "GET /api/v1/github/setup", type: :request do
  around do |example|
    original_app_url = ENV["APP_URL"]
    ENV["APP_URL"] = "http://localhost:3000"
    example.run
    ENV["APP_URL"] = original_app_url
  end

  it "adds installation_id to the team and redirects to the web app" do
    membership = create(:membership)
    state = Github::InstallState.generate(team: membership.team, user: membership.user)

    get "/api/v1/github/setup", params: { installation_id: "777", state: state }

    expect(response).to have_http_status(:found)
    expect(response.location).to eq("http://localhost:3000/t/#{membership.team.id}/settings")
    expect(membership.team.reload.github_installation_ids).to include(777)
  end

  it "403 if the state's user is not a team member" do
    team = create(:team)
    outsider = create(:user)
    state = Github::InstallState.generate(team: team, user: outsider)
    # outsider never joins the team

    get "/api/v1/github/setup", params: { installation_id: "1", state: state }

    expect(response).to have_http_status(:forbidden)
  end

  it "400 with an invalid state" do
    get "/api/v1/github/setup", params: { installation_id: "1", state: "not-valid" }

    expect(response).to have_http_status(:bad_request)
  end
end
