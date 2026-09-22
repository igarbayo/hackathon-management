require "rails_helper"

RSpec.describe Attribution::ApplyBranch do
  let(:team) { create(:team) }

  it "atribuye si la rama está en branch_names de una sola feature" do
    feature = create(:feature, team: team, branch_names: ["f-12-login"])
    event = build(:activity_event, :github_commit, team: team, branch: "f-12-login")

    expect(described_class.call(event)).to eq(feature)
  end

  it "no decide si la rama está en dos features (conflicto)" do
    create(:feature, team: team, branch_names: ["shared-branch"])
    create(:feature, team: team, branch_names: ["shared-branch"])
    event = build(:activity_event, :github_commit, team: team, branch: "shared-branch")

    expect(described_class.call(event)).to be_nil
  end

  it "nunca usa la rama por defecto del repositorio" do
    repository = create(:repository, team: team, default_branch: "main")
    create(:feature, team: team, branch_names: ["main"])
    event = build(:activity_event, :github_commit, team: team, repository: repository, branch: "main")

    expect(described_class.call(event)).to be_nil
  end

  it "sin rama, no hay atribución" do
    event = build(:activity_event, :github_commit, team: team, branch: nil)

    expect(described_class.call(event)).to be_nil
  end
end
