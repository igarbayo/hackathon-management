require "rails_helper"

RSpec.describe Integration::Create do
  it "crea un token hb_it_ sin membership, con el equipo como dueño" do
    owner = create(:membership, :owner)

    result = described_class.call(team: owner.team, created_by: owner.user, name: "Bot de Slack", scopes: ["features:write"])

    expect(result.raw_token).to start_with("hb_it_")
    expect(result.record.kind).to eq("integration")
    expect(result.record.membership_id).to be_nil
    expect(result.record.created_by_id).to eq(owner.user.id)
    expect(result.record.scopes).to include("read", "features:write")
  end

  it "nunca concede progress:write (validación del modelo)" do
    owner = create(:membership, :owner)

    expect { described_class.call(team: owner.team, created_by: owner.user, name: "Bot", scopes: ["progress:write"]) }
      .to raise_error(Mongoid::Errors::Validations)
  end

  it "máximo 10 activos por equipo (validación del modelo)" do
    owner = create(:membership, :owner)
    10.times { |i| create(:access_token, :integration, team: owner.team, name: "Bot #{i}") }

    expect { described_class.call(team: owner.team, created_by: owner.user, name: "Bot 11", scopes: ["read"]) }
      .to raise_error(Mongoid::Errors::Validations)
  end
end
