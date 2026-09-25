require "rails_helper"

RSpec.describe Objective, type: :model do
  it "assigns number and key atomically, independently of Feature" do
    team = create(:team)
    create(:feature, team: team)
    objective = create(:objective, team: team)

    expect(objective.number).to eq(1)
    expect(objective.key).to eq("O-1")
  end

  it "archived objectives are not considered active" do
    objective = create(:objective, archived_at: Time.current)

    expect(Objective.active).not_to include(objective)
  end
end
