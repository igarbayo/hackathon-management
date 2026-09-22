require "rails_helper"

RSpec.describe AccessToken, type: :model do
  it "nunca acepta el scope ingest" do
    token = build(:access_token, scopes: [ "read", "ingest" ])

    expect(token).not_to be_valid
    expect(token.errors[:scopes]).to be_present
  end

  it "no permite una caducidad de más de 90 días" do
    token = build(:access_token, expires_at: 200.days.from_now)

    expect(token).not_to be_valid
  end

  it "no permite más de 10 PAT activos por membresía" do
    membership = create(:membership)
    team = membership.team
    10.times { |n| create(:access_token, team: team, membership: membership, token_digest: "d#{n}") }

    eleventh = build(:access_token, team: team, membership: membership, token_digest: "d-eleven")

    expect(eleventh).not_to be_valid
    expect(eleventh.errors[:base]).to be_present
  end

  it "no cuenta los PAT revocados o caducados para el límite" do
    membership = create(:membership)
    team = membership.team
    10.times do |n|
      create(:access_token, team: team, membership: membership, token_digest: "d#{n}",
                             revoked_at: Time.current, revoke_reason: "manual")
    end

    eleventh = build(:access_token, team: team, membership: membership, token_digest: "d-eleven")

    expect(eleventh).to be_valid
  end

  it "no permite más de 10 tokens de integración activos por equipo" do
    team = create(:team)
    10.times { |n| create(:access_token, :integration, team: team, token_digest: "i#{n}") }

    eleventh = build(:access_token, :integration, team: team, token_digest: "i-eleven")

    expect(eleventh).not_to be_valid
  end

  it "un token de integración nunca acepta progress:write (el progreso es de una persona)" do
    token = build(:access_token, :integration, scopes: [ "read", "progress:write" ])

    expect(token).not_to be_valid
    expect(token.errors[:scopes]).to be_present
  end

  it "un PAT sí puede llevar progress:write" do
    token = build(:access_token, scopes: [ "read", "progress:write" ])

    expect(token).to be_valid
  end
end
