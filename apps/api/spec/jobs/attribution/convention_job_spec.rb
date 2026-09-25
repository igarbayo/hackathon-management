require "rails_helper"

RSpec.describe Attribution::ConventionJob do
  let(:team) { create(:team) }

  it "is queued automatically when an event of an attributable kind is created" do
    create(:activity_event, :github_commit, team: team, title: "something")

    expect(described_class.jobs.size).to eq(1)
  end

  it "is not queued for non-attributable kinds (e.g. system)" do
    create(:activity_event, team: team, source: "system", kind: "member_joined")

    expect(described_class.jobs).to be_empty
  end

  it "layer 1: attributes by convention when it runs" do
    feature = create(:feature, team: team)
    event = create(:activity_event, :github_commit, team: team, title: "Fix F-#{feature.number}")

    described_class.drain

    event.reload
    expect(event.attribution.feature_id).to eq(feature.id)
    expect(event.attribution.method).to eq("convention")
    expect(event.attribution.status).to eq("confirmed")
  end

  it "layer 2: if there is no convention, tries the known branch" do
    feature = create(:feature, team: team, branch_names: [ "my-branch" ])
    event = create(:activity_event, :github_commit, team: team, title: "no key", branch: "my-branch")

    described_class.drain

    event.reload
    expect(event.attribution.feature_id).to eq(feature.id)
    expect(event.attribution.method).to eq("branch")
  end

  it "with no convention or known branch, the event stays unattributed" do
    create(:activity_event, :github_commit, team: team, title: "no clues")

    described_class.drain

    event = ActivityEvent.where(team_id: team.id).first
    expect(event.attribution).to be_nil
  end

  it "is idempotent: does not touch an event that already has an attribution" do
    other_feature = create(:feature, team: team)
    feature = create(:feature, team: team)
    event = create(:activity_event, :github_commit, team: team, title: "F-#{feature.number}")
    event.build_attribution(feature_id: other_feature.id, method: "manual", status: "confirmed")
    event.save!

    described_class.new.perform(event.id.to_s)

    expect(event.reload.attribution.feature_id).to eq(other_feature.id)
  end

  it "stores mentioned_feature_keys even if it cannot attribute" do
    create(:activity_event, :github_commit, team: team, title: "mentions F-777")

    described_class.drain

    event = ActivityEvent.where(team_id: team.id).first
    expect(event.mentioned_feature_keys).to eq([ "F-777" ])
  end
end
