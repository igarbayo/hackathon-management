require "rails_helper"

RSpec.describe OAuthGrant, type: :model do
  it "lleva team_id (no es una excepción a la regla multi-tenant)" do
    grant = create(:oauth_grant)

    expect(grant.team_id).to be_present
  end

  it "el code_digest es único" do
    create(:oauth_grant, code_digest: "same-digest")
    duplicate = build(:oauth_grant, code_digest: "same-digest")

    expect(duplicate).not_to be_valid
  end

  it "se puede marcar como usado una sola vez" do
    grant = create(:oauth_grant)

    expect(grant.used?).to be false

    grant.update!(used_at: Time.current)

    expect(grant.used?).to be true
  end

  it "expira" do
    grant = create(:oauth_grant, expires_at: 1.second.ago)

    expect(grant.expired?).to be true
  end
end
