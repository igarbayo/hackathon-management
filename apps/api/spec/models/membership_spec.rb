require "rails_helper"

RSpec.describe Membership, type: :model do
  it "does not allow the same user to have two memberships in the same team" do
    team = create(:team)
    user = create(:user)
    create(:membership, team: team, user: user)

    duplicate = build(:membership, team: team, user: user)

    expect(duplicate).not_to be_valid
  end

  it "uses the user's name as display_name by default" do
    user = create(:user, name: "Grace Hopper")
    membership = create(:membership, user: user, display_name: nil)

    expect(membership.display_name).to eq("Grace Hopper")
  end

  describe "invariant: there is always at least one owner" do
    it "does not let the last owner be demoted" do
      team = create(:team)
      owner = create(:membership, :owner, team: team)

      owner.role = "member"

      expect(owner).not_to be_valid
      expect(owner.errors[:role]).to be_present
    end

    it "does not let the last owner be removed" do
      team = create(:team)
      owner = create(:membership, :owner, team: team)

      expect(owner.destroy).to be false
    end

    it "lets an owner be demoted if there is another one" do
      team = create(:team)
      owner_a = create(:membership, :owner, team: team)
      create(:membership, :owner, team: team)

      owner_a.role = "member"

      expect(owner_a).to be_valid
    end

    it "lets an owner be removed if there is another one" do
      team = create(:team)
      owner_a = create(:membership, :owner, team: team)
      create(:membership, :owner, team: team)

      expect(owner_a.destroy).to be_truthy
    end
  end

  describe "embedded ClaudeCodeLink" do
    it "is nil by default" do
      membership = create(:membership)

      expect(membership.claude_code).to be_nil
    end

    it "requires token_digest and token_prefix when it exists" do
      membership = build(:membership)
      membership.build_claude_code(privacy_level: "metadata")

      expect(membership).not_to be_valid
      expect(membership.claude_code.errors[:token_digest]).to be_present
    end
  end

  describe "when leaving or being removed (RF-TEAM-008)" do
    it "revokes their tokens for that team and deletes their OAuth grants" do
      membership = create(:membership)
      pat = create(:access_token, team: membership.team, membership: membership)
      grant = create(:oauth_grant, team: membership.team, user: membership.user, membership: membership)
      other = create(:access_token)

      membership.destroy!

      expect(pat.reload.revoked_at).to be_present
      expect(pat.revoke_reason).to eq("member_left")
      expect(OAuthGrant.where(id: grant.id).exists?).to be(false)
      expect(other.reload.revoked_at).to be_nil
    end
  end
end
