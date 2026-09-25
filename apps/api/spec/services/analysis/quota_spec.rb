require "rails_helper"

RSpec.describe Analysis::Quota do
  it "uses 5 manual runs/day on the free plan and 30 on pro" do
    expect(described_class.manual_limit(build(:team, plan: "free"))).to eq(5)
    expect(described_class.manual_limit(build(:team, plan: "pro"))).to eq(30)
  end

  it "does not raise below the limit" do
    team = create(:team, plan: "free")
    4.times { create(:ai_analysis, team: team, trigger: "manual") }

    expect { described_class.check_manual!(team) }.not_to raise_error
  end

  it "raises ExceededError when reaching the limit" do
    team = create(:team, plan: "free")
    5.times { create(:ai_analysis, team: team, trigger: "manual") }

    expect { described_class.check_manual!(team) }.to raise_error(Analysis::Quota::ExceededError)
  end

  it "does not count scheduled analyses toward the manual limit" do
    team = create(:team, plan: "free")
    10.times { create(:ai_analysis, team: team, trigger: "scheduled") }

    expect { described_class.check_manual!(team) }.not_to raise_error
  end
end
