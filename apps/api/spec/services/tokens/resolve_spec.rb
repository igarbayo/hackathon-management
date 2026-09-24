require "rails_helper"

RSpec.describe Tokens::Resolve do
  describe "token de miembro (hb_mt_)" do
    it "resuelve equipo, membership y los scopes fijos" do
      membership = create(:membership)
      membership.update!(claude_code_attributes: { token_digest: Digest::SHA256.hexdigest("hb_mt_x"), token_prefix: "hb_mt_x", privacy_level: "metadata" })

      resolved = described_class.call("hb_mt_x")

      expect(resolved.kind).to eq("member")
      expect(resolved.team).to eq(membership.team)
      expect(resolved.membership).to eq(membership)
      expect(resolved.scopes).to eq(%w[ingest read progress:write])
    end

    it "nil si el enlace está pausado" do
      membership = create(:membership)
      membership.update!(claude_code_attributes: { token_digest: Digest::SHA256.hexdigest("hb_mt_x"), token_prefix: "hb_mt_x", privacy_level: "metadata", paused: true })

      expect(described_class.call("hb_mt_x")).to be_nil
    end
  end

  describe "PAT (hb_pat_)" do
    it "resuelve equipo, membership y los scopes del token" do
      result = Pat::Create.call(membership: create(:membership), name: "Mi token", preset: "agente")

      resolved = described_class.call(result.raw_token)

      expect(resolved.kind).to eq("pat")
      expect(resolved.scopes).to include("features:write", "read")
      expect(resolved.token_record).to eq(result.record)
    end

    it "nil si está revocado" do
      result = Pat::Create.call(membership: create(:membership), name: "Mi token")
      result.record.update!(revoked_at: Time.current, revoke_reason: "manual")

      expect(described_class.call(result.raw_token)).to be_nil
    end

    it "nil si ha caducado" do
      result = Pat::Create.call(membership: create(:membership), name: "Mi token", expires_at: 1.minute.ago)

      expect(described_class.call(result.raw_token)).to be_nil
    end

    it "actualiza last_used_at con resolución de 1 minuto" do
      result = Pat::Create.call(membership: create(:membership), name: "Mi token")

      described_class.call(result.raw_token)

      expect(result.record.reload.last_used_at).to be_present
    end
  end

  it "nil para un prefijo desconocido" do
    expect(described_class.call("hb_oat_algo")).to be_nil
  end

  it "nil si no hay token" do
    expect(described_class.call(nil)).to be_nil
    expect(described_class.call("")).to be_nil
  end

  describe "equipos borrados y personas que ya no son miembros" do
    it "nil para un PAT de un equipo borrado" do
      result = Pat::Create.call(membership: create(:membership), name: "Mi token", preset: "agente")
      result.record.team.update!(deleted_at: Time.current)

      expect(described_class.call(result.raw_token)).to be_nil
    end

    it "nil para un PAT cuya membresía ya no existe" do
      membership = create(:membership)
      result = Pat::Create.call(membership: membership, name: "Mi token", preset: "agente")
      membership.delete

      expect(described_class.call(result.raw_token)).to be_nil
    end
  end
end
