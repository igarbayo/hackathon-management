require "rails_helper"

RSpec.describe "Connected apps (/me/oauth_connections)", type: :request do
  def create_oauth_connection(user:, team:)
    client = create(:oauth_client, name: "claude.ai")
    family_id = SecureRandom.uuid
    create(:access_token, :oauth, team: team, user_id: user.id, oauth_client: client, scopes: [ "read" ], refresh_family_id: family_id, name: client.name)
    family_id
  end

  it "requires a session" do
    get "/api/v1/me/oauth_connections"

    expect(response).to have_http_status(:unauthorized)
  end

  it "lists the connections grouped by family, not by each rotated token" do
    membership = create(:membership)
    family_id = create_oauth_connection(user: membership.user, team: membership.team)
    sign_in_as(membership.user)

    get "/api/v1/me/oauth_connections"

    expect(json_response["data"].size).to eq(1)
    expect(json_response["data"].first["id"]).to eq(family_id)
    expect(json_response["data"].first["client"]["name"]).to eq("claude.ai")
  end

  it "does not see another person's connections" do
    membership = create(:membership)
    other_user = create(:user)
    create_oauth_connection(user: other_user, team: membership.team)
    sign_in_as(membership.user)

    get "/api/v1/me/oauth_connections"

    expect(json_response["data"]).to be_empty
  end

  it "revoking deletes the whole family (all rotations), not only one token" do
    membership = create(:membership)
    family_id = create_oauth_connection(user: membership.user, team: membership.team)
    create(:access_token, :oauth, team: membership.team, user_id: membership.user.id, refresh_family_id: family_id, created_at: 1.hour.from_now)
    sign_in_as(membership.user)

    delete "/api/v1/me/oauth_connections/#{family_id}", headers: csrf_headers

    expect(response).to have_http_status(:no_content)
    expect(AccessToken.where(refresh_family_id: family_id, revoked_at: nil)).to be_empty
  end

  it "404 if the connection is not theirs" do
    membership = create(:membership)
    other_user = create(:user)
    family_id = create_oauth_connection(user: other_user, team: membership.team)
    sign_in_as(membership.user)

    delete "/api/v1/me/oauth_connections/#{family_id}", headers: csrf_headers

    expect(response).to have_http_status(:not_found)
  end
end
