require "rails_helper"

RSpec.describe Ai::KeyOwner do
  it "devuelve el user del owner del equipo" do
    owner = create(:membership, :owner)

    expect(described_class.for(owner.team)).to eq(owner.user)
  end

  it "devuelve nil si el equipo no tiene owner" do
    team = create(:team)

    expect(described_class.for(team)).to be_nil
  end
end
