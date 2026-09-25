require "rails_helper"

RSpec.describe Tokens::Resolve do
  describe "member token (hb_mt_)" do
    it "resolves team, membership and the fixed scopes" do
      membership = create(:membership)
      membership.update!(claude_code_attributes: { token_digest: Digest::SHA256.hexdigest("hb_mt_x"), token_prefix: "hb_mt_x", privacy_level: "metadata" })

      resolved = described_class.call("hb_mt_x")

      expect(resolved.kind).to eq("member")
      expect(resolved.team).to eq(membership.team)
      expect(resolved.membership).to eq(membership)
      expect(resolved.scopes).to eq(%w[ingest read progress:write])
    end

    it "nil if the link is paused" do
      membership = create(:membership)
      membership.update!(claude_code_attributes: { token_digest: Digest::SHA256.hexdigest("hb_mt_x"), token_prefix: "hb_mt_x", privacy_level: "metadata", paused: true })

      expect(described_class.call("hb_mt_x")).to be_nil
    end
  end

  describe "PAT (hb_pat_)" do
    it "resolves team, membership and the token's scopes" do
      result = Pat::Create.call(membership: create(:membership), name: "My token", preset: "agent")

      resolved = described_class.call(result.raw_token)

      expect(resolved.kind).to eq("pat")
      expect(resolved.scopes).to include("features:write", "read")
      expect(resolved.token_record).to eq(result.record)
    end

    it "nil if it is revoked" do
      result = Pat::Create.call(membership: create(:membership), name: "My token")
      result.record.update!(revoked_at: Time.current, revoke_reason: "manual")

      expect(described_class.call(result.raw_token)).to be_nil
    end

    it "nil if it has expired" do
      result = Pat::Create.call(membership: create(:membership), name: "My token", expires_at: 1.minute.ago)

      expect(described_class.call(result.raw_token)).to be_nil
    end

    it "updates last_used_at with 1 minute resolution" do
      result = Pat::Create.call(membership: create(:membership), name: "My token")

      described_class.call(result.raw_token)

      expect(result.record.reload.last_used_at).to be_present
    end
  end

  it "nil for an unknown prefix" do
    expect(described_class.call("hb_oat_algo")).to be_nil
  end

  it "nil if there is no token" do
    expect(described_class.call(nil)).to be_nil
    expect(described_class.call("")).to be_nil
  end

  describe "deleted teams and people who are no longer members" do
    it "nil for a PAT of a deleted team" do
      result = Pat::Create.call(membership: create(:membership), name: "My token", preset: "agent")
      result.record.team.update!(deleted_at: Time.current)

      expect(described_class.call(result.raw_token)).to be_nil
    end

    it "nil for a PAT whose membership no longer exists" do
      membership = create(:membership)
      result = Pat::Create.call(membership: membership, name: "My token", preset: "agent")
      membership.delete

      expect(described_class.call(result.raw_token)).to be_nil
    end
  end
end
