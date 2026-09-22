require "rails_helper"

RSpec.describe Pat::Create do
  it "usa el preset observar por defecto (solo read)" do
    result = described_class.call(membership: create(:membership), name: "CLI portátil")

    expect(result.record.scopes).to eq([ "read" ])
    expect(result.raw_token).to start_with("hb_pat_")
  end

  it "el preset agente da los scopes de escritura de un agente" do
    result = described_class.call(membership: create(:membership), name: "Agente", preset: "agente")

    expect(result.record.scopes).to match_array(%w[read features:write arguments:write progress:write])
  end

  it "scopes explícitos siempre incluyen read aunque no se pida" do
    result = described_class.call(membership: create(:membership), name: "Custom", scopes: [ "milestones:write" ])

    expect(result.record.scopes).to match_array(%w[read milestones:write])
  end

  it "nunca concede el scope ingest (validación del modelo)" do
    expect { described_class.call(membership: create(:membership), name: "Malicioso", scopes: [ "ingest" ]) }
      .to raise_error(Mongoid::Errors::Validations)
  end

  it "caducidad por defecto: hackathon.ends_at + 7 días" do
    membership = create(:membership)
    membership.team.hackathon.update!(ends_at: 10.days.from_now)

    result = described_class.call(membership: membership, name: "Token")

    expect(result.record.expires_at).to be_within(1.minute).of(17.days.from_now)
  end

  it "la caducidad nunca supera los 90 días desde la creación" do
    membership = create(:membership)
    membership.team.hackathon.update!(ends_at: 200.days.from_now)

    result = described_class.call(membership: membership, name: "Token")

    expect(result.record.expires_at).to be_within(1.minute).of(90.days.from_now)
  end

  it "solo guarda el hash del token, nunca el valor en claro" do
    result = described_class.call(membership: create(:membership), name: "Token")

    expect(result.record.token_digest).to eq(Digest::SHA256.hexdigest(result.raw_token))
  end
end
