require "rails_helper"

RSpec.describe Ai::KeyOwner do
  it "returns the team owner's user" do
    owner = create(:membership, :owner)

    expect(described_class.for(owner.team)).to eq(owner.user)
  end

  it "returns nil if the team has no owner" do
    team = create(:team)

    expect(described_class.for(team)).to be_nil
  end
end
