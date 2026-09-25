require "rails_helper"

RSpec.describe AccessToken, type: :model do
  it "never accepts the ingest scope" do
    token = build(:access_token, scopes: [ "read", "ingest" ])

    expect(token).not_to be_valid
    expect(token.errors[:scopes]).to be_present
  end

  it "does not allow an expiry of more than 90 days" do
    token = build(:access_token, expires_at: 200.days.from_now)

    expect(token).not_to be_valid
  end

  it "does not allow more than 10 active PATs per membership" do
    membership = create(:membership)
    team = membership.team
    10.times { |n| create(:access_token, team: team, membership: membership, token_digest: "d#{n}") }

    eleventh = build(:access_token, team: team, membership: membership, token_digest: "d-eleven")

    expect(eleventh).not_to be_valid
    expect(eleventh.errors[:base]).to be_present
  end

  it "does not count revoked or expired PATs toward the limit" do
    membership = create(:membership)
    team = membership.team
    10.times do |n|
      create(:access_token, team: team, membership: membership, token_digest: "d#{n}",
                             revoked_at: Time.current, revoke_reason: "manual")
    end

    eleventh = build(:access_token, team: team, membership: membership, token_digest: "d-eleven")

    expect(eleventh).to be_valid
  end

  it "does not allow more than 10 active integration tokens per team" do
    team = create(:team)
    10.times { |n| create(:access_token, :integration, team: team, token_digest: "i#{n}") }

    eleventh = build(:access_token, :integration, team: team, token_digest: "i-eleven")

    expect(eleventh).not_to be_valid
  end

  it "an integration token never accepts progress:write (progress belongs to a person)" do
    token = build(:access_token, :integration, scopes: [ "read", "progress:write" ])

    expect(token).not_to be_valid
    expect(token.errors[:scopes]).to be_present
  end

  it "a PAT can have progress:write" do
    token = build(:access_token, scopes: [ "read", "progress:write" ])

    expect(token).to be_valid
  end
end
