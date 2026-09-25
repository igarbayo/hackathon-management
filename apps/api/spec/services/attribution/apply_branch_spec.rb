require "rails_helper"

RSpec.describe Attribution::ApplyBranch do
  let(:team) { create(:team) }

  it "attributes if the branch is in the branch_names of a single feature" do
    feature = create(:feature, team: team, branch_names: [ "f-12-login" ])
    event = build(:activity_event, :github_commit, team: team, branch: "f-12-login")

    expect(described_class.call(event)).to eq(feature)
  end

  it "does not decide if the branch is in two features (conflict)" do
    create(:feature, team: team, branch_names: [ "shared-branch" ])
    create(:feature, team: team, branch_names: [ "shared-branch" ])
    event = build(:activity_event, :github_commit, team: team, branch: "shared-branch")

    expect(described_class.call(event)).to be_nil
  end

  it "never uses the repository's default branch" do
    repository = create(:repository, team: team, default_branch: "main")
    create(:feature, team: team, branch_names: [ "main" ])
    event = build(:activity_event, :github_commit, team: team, repository: repository, branch: "main")

    expect(described_class.call(event)).to be_nil
  end

  it "with no branch, there is no attribution" do
    event = build(:activity_event, :github_commit, team: team, branch: nil)

    expect(described_class.call(event)).to be_nil
  end
end
