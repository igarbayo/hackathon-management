require "rails_helper"

RSpec.describe Pat::Create do
  it "uses the observar preset by default (read only)" do
    result = described_class.call(membership: create(:membership), name: "Laptop CLI")

    expect(result.record.scopes).to eq([ "read" ])
    expect(result.raw_token).to start_with("hb_pat_")
  end

  it "the agente preset gives an agent's write scopes" do
    result = described_class.call(membership: create(:membership), name: "Agente", preset: "agent")

    expect(result.record.scopes).to match_array(%w[read features:write arguments:write progress:write])
  end

  it "explicit scopes always include read even if not asked for" do
    result = described_class.call(membership: create(:membership), name: "Custom", scopes: [ "milestones:write" ])

    expect(result.record.scopes).to match_array(%w[read milestones:write])
  end

  it "never grants the ingest scope (model validation)" do
    expect { described_class.call(membership: create(:membership), name: "Malicious", scopes: [ "ingest" ]) }
      .to raise_error(Mongoid::Errors::Validations)
  end

  it "default expiry: hackathon.ends_at + 7 days" do
    membership = create(:membership)
    membership.team.hackathon.update!(ends_at: 10.days.from_now)

    result = described_class.call(membership: membership, name: "Token")

    expect(result.record.expires_at).to be_within(1.minute).of(17.days.from_now)
  end

  it "the expiry is never more than 90 days after creation" do
    membership = create(:membership)
    membership.team.hackathon.update!(ends_at: 200.days.from_now)

    result = described_class.call(membership: membership, name: "Token")

    expect(result.record.expires_at).to be_within(1.minute).of(90.days.from_now)
  end

  it "only stores the token hash, never the plain value" do
    result = described_class.call(membership: create(:membership), name: "Token")

    expect(result.record.token_digest).to eq(Digest::SHA256.hexdigest(result.raw_token))
  end
end
