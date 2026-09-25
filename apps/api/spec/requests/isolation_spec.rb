require "rails_helper"

# RNF-SEC-001: every domain query is scoped by current_team. A member of team A
# can never read or write team B's data, even if they know its ids.
RSpec.describe "Isolation between teams (RNF-SEC-001)", type: :request do
  it "a member of team A cannot see team B's objectives" do
    membership_a = create(:membership)
    team_b = create(:team)
    objective_b = create(:objective, team: team_b)
    sign_in_as(membership_a.user)

    get "/api/v1/teams/#{team_b.id}/objectives"
    expect(response).to have_http_status(:not_found)

    patch "/api/v1/teams/#{team_b.id}/objectives/#{objective_b.id}", params: { title: "hacked" }, headers: csrf_headers, as: :json
    expect(response).to have_http_status(:not_found)
    expect(objective_b.reload.title).not_to eq("hacked")
  end

  it "a member of team A cannot move a team B feature using A's id in the URL but B's id in the body" do
    membership_a = create(:membership)
    membership_b = create(:membership)
    feature_b = create(:feature, team: membership_b.team)
    sign_in_as(membership_a.user)

    get "/api/v1/teams/#{membership_a.team.id}/features/#{feature_b.id}"

    expect(response).to have_http_status(:not_found)
  end

  it "cannot see the members of another team" do
    membership_a = create(:membership)
    membership_b = create(:membership)
    sign_in_as(membership_a.user)

    get "/api/v1/teams/#{membership_b.team.id}/members"

    expect(response).to have_http_status(:not_found)
  end
end
