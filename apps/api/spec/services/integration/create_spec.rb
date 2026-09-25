require "rails_helper"

RSpec.describe Integration::Create do
  it "creates an hb_it_ token with no membership, with the team as the owner" do
    owner = create(:membership, :owner)

    result = described_class.call(team: owner.team, created_by: owner.user, name: "Slack bot", scopes: [ "features:write" ])

    expect(result.raw_token).to start_with("hb_it_")
    expect(result.record.kind).to eq("integration")
    expect(result.record.membership_id).to be_nil
    expect(result.record.created_by_id).to eq(owner.user.id)
    expect(result.record.scopes).to include("read", "features:write")
  end

  it "never grants progress:write (model validation)" do
    owner = create(:membership, :owner)

    expect { described_class.call(team: owner.team, created_by: owner.user, name: "Bot", scopes: [ "progress:write" ]) }
      .to raise_error(Mongoid::Errors::Validations)
  end

  it "at most 10 active per team (model validation)" do
    owner = create(:membership, :owner)
    10.times { |i| create(:access_token, :integration, team: owner.team, name: "Bot #{i}") }

    expect { described_class.call(team: owner.team, created_by: owner.user, name: "Bot 11", scopes: [ "read" ]) }
      .to raise_error(Mongoid::Errors::Validations)
  end
end
