require "rails_helper"

RSpec.describe Webhooks::MilestoneDueSoonJob do
  it "warns about a milestone due within the next hour" do
    team = create(:team)
    create(:outbound_webhook, team: team, events: [ "milestone.due_soon" ])
    milestone = create(:milestone, team: team, due_at: 30.minutes.from_now)

    described_class.new.perform

    expect(Webhooks::DeliverJob.jobs.size).to eq(1)
    expect(milestone.reload.due_soon_notified_at).to be_present
  end

  it "does not warn twice about the same milestone" do
    team = create(:team)
    create(:outbound_webhook, team: team, events: [ "milestone.due_soon" ])
    milestone = create(:milestone, team: team, due_at: 30.minutes.from_now, due_soon_notified_at: 5.minutes.ago)

    described_class.new.perform

    expect(Webhooks::DeliverJob.jobs).to be_empty
    expect(milestone.reload.due_soon_notified_at).to be_within(1.second).of(5.minutes.ago)
  end

  it "does not warn about milestones due outside the 1h window" do
    team = create(:team)
    create(:outbound_webhook, team: team, events: [ "milestone.due_soon" ])
    create(:milestone, team: team, due_at: 3.hours.from_now)

    described_class.new.perform

    expect(Webhooks::DeliverJob.jobs).to be_empty
  end

  it "warns again if due_at changes (due_soon_notified_at is cleared)" do
    milestone = create(:milestone, due_at: 2.days.from_now, due_soon_notified_at: 1.hour.ago)

    milestone.update!(due_at: 30.minutes.from_now)

    expect(milestone.due_soon_notified_at).to be_nil
  end
end
