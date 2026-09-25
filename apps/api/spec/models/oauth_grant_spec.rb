require "rails_helper"

RSpec.describe OAuthGrant, type: :model do
  it "has a team_id (it is not an exception to the multi-tenant rule)" do
    grant = create(:oauth_grant)

    expect(grant.team_id).to be_present
  end

  it "the code_digest is unique" do
    create(:oauth_grant, code_digest: "same-digest")
    duplicate = build(:oauth_grant, code_digest: "same-digest")

    expect(duplicate).not_to be_valid
  end

  it "can be marked as used only once" do
    grant = create(:oauth_grant)

    expect(grant.used?).to be false

    grant.update!(used_at: Time.current)

    expect(grant.used?).to be true
  end

  it "expires" do
    grant = create(:oauth_grant, expires_at: 1.second.ago)

    expect(grant.expired?).to be true
  end
end
