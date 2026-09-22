require "rails_helper"

RSpec.describe Analysis::Quota do
  it "usa 5 manuales/día en el plan free y 30 en pro" do
    expect(described_class.manual_limit(build(:team, plan: "free"))).to eq(5)
    expect(described_class.manual_limit(build(:team, plan: "pro"))).to eq(30)
  end

  it "no lanza error por debajo del límite" do
    team = create(:team, plan: "free")
    4.times { create(:ai_analysis, team: team, trigger: "manual") }

    expect { described_class.check_manual!(team) }.not_to raise_error
  end

  it "lanza ExceededError al llegar al límite" do
    team = create(:team, plan: "free")
    5.times { create(:ai_analysis, team: team, trigger: "manual") }

    expect { described_class.check_manual!(team) }.to raise_error(Analysis::Quota::ExceededError)
  end

  it "no cuenta los análisis programados para el límite manual" do
    team = create(:team, plan: "free")
    10.times { create(:ai_analysis, team: team, trigger: "scheduled") }

    expect { described_class.check_manual!(team) }.not_to raise_error
  end
end
