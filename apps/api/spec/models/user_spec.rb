require "rails_helper"

RSpec.describe User, type: :model do
  it "requires email and name" do
    user = User.new

    expect(user).not_to be_valid
    expect(user.errors[:email]).to be_present
    expect(user.errors[:name]).to be_present
  end

  it "stores the email in lowercase" do
    user = create(:user, email: "ADA@Example.com")
    expect(user.email).to eq("ada@example.com")
  end

  it "does not allow repeated emails" do
    create(:user, email: "dup@example.com")
    duplicate = build(:user, email: "dup@example.com")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:email]).to be_present
  end

  it "requires a password, GitHub or Google to be able to authenticate" do
    user = build(:user, password: nil, github_uid: nil, google_sub: nil)

    expect(user).not_to be_valid
    expect(user.errors[:base]).to be_present
  end

  describe "maximum password length (bcrypt limit)" do
    it "accepts 72 bytes" do
      expect(build(:user, password: "a" * 72)).to be_valid
    end

    it "rejects more than 72 bytes" do
      user = build(:user, password: "a" * 73)

      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end

    it "counts bytes, not characters" do
      user = build(:user, password: "ñ" * 37)

      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end
  end

  it "is valid with only github_uid, no password" do
    user = build(:user, password: nil, github_uid: 12_345)

    expect(user).to be_valid
  end

  it "allows many users with no github_uid (sparse index)" do
    create(:user, github_uid: nil)
    other = build(:user, github_uid: nil)

    expect(other).to be_valid
  end

  it "does not allow two users with the same github_uid" do
    create(:user, github_uid: 42)
    duplicate = build(:user, github_uid: 42)

    expect(duplicate).not_to be_valid
  end

  describe "#gemini_api_key" do
    it "is stored encrypted and decrypted back when read" do
      user = create(:user)

      user.gemini_api_key = "fake-gemini-key"
      user.save!
      user.reload

      expect(user.gemini_api_key_encrypted).not_to include("fake-gemini-key")
      expect(user.gemini_api_key).to eq("fake-gemini-key")
      expect(user.gemini_api_key_configured?).to be true
    end

    it "with no key, it is not set up" do
      user = create(:user)

      expect(user.gemini_api_key).to be_nil
      expect(user.gemini_api_key_configured?).to be false
    end

    it "can be removed by assigning a blank value" do
      user = create(:user)
      user.update!(gemini_api_key: "fake-gemini-key")

      user.update!(gemini_api_key: "")

      expect(user.reload.gemini_api_key_configured?).to be false
    end
  end

  describe "#remember_last_team!" do
    it "stores the team as the last opened one" do
      user = create(:user)
      team = create(:team)

      user.remember_last_team!(team.id)

      expect(user.reload.last_team_id).to eq(team.id)
    end

    it "does not write if it was already that team" do
      team = create(:team)
      user = create(:user, last_team_id: team.id)

      expect(user).not_to receive(:set)
      user.remember_last_team!(team.id)
    end
  end
end
