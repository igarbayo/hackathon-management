require "rails_helper"

RSpec.describe Membership, type: :model do
  it "no permite que el mismo usuario tenga dos membresías en el mismo equipo" do
    team = create(:team)
    user = create(:user)
    create(:membership, team: team, user: user)

    duplicate = build(:membership, team: team, user: user)

    expect(duplicate).not_to be_valid
  end

  it "usa el nombre del usuario como display_name por defecto" do
    user = create(:user, name: "Grace Hopper")
    membership = create(:membership, user: user, display_name: nil)

    expect(membership.display_name).to eq("Grace Hopper")
  end

  describe "invariante: siempre hay al menos un owner" do
    it "no deja bajar de categoría al último owner" do
      team = create(:team)
      owner = create(:membership, :owner, team: team)

      owner.role = "member"

      expect(owner).not_to be_valid
      expect(owner.errors[:role]).to be_present
    end

    it "no deja eliminar al último owner" do
      team = create(:team)
      owner = create(:membership, :owner, team: team)

      expect(owner.destroy).to be false
    end

    it "sí deja degradar a un owner si hay otro" do
      team = create(:team)
      owner_a = create(:membership, :owner, team: team)
      create(:membership, :owner, team: team)

      owner_a.role = "member"

      expect(owner_a).to be_valid
    end

    it "sí deja eliminar a un owner si hay otro" do
      team = create(:team)
      owner_a = create(:membership, :owner, team: team)
      create(:membership, :owner, team: team)

      expect(owner_a.destroy).to be_truthy
    end
  end

  describe "ClaudeCodeLink embebido" do
    it "es nil por defecto" do
      membership = create(:membership)

      expect(membership.claude_code).to be_nil
    end

    it "exige token_digest y token_prefix cuando existe" do
      membership = build(:membership)
      membership.build_claude_code(privacy_level: "metadata")

      expect(membership).not_to be_valid
      expect(membership.claude_code.errors[:token_digest]).to be_present
    end
  end

  describe "al salir o ser expulsado (RF-TEAM-008)" do
    it "revoca sus tokens de ese equipo y borra sus grants OAuth" do
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
