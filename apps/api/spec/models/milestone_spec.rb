require "rails_helper"

RSpec.describe Milestone, type: :model do
  it "does not clear due_soon_notified_at when created with one already set" do
    milestone = create(:milestone, due_soon_notified_at: 5.minutes.ago)

    expect(milestone.due_soon_notified_at).to be_present
  end

  it "clears due_soon_notified_at when due_at changes" do
    milestone = create(:milestone, due_soon_notified_at: 5.minutes.ago)

    milestone.update!(due_at: 3.days.from_now)

    expect(milestone.due_soon_notified_at).to be_nil
  end

  it "does not touch due_soon_notified_at if another field is edited" do
    milestone = create(:milestone, due_soon_notified_at: 5.minutes.ago)

    milestone.update!(title: "New title")

    expect(milestone.due_soon_notified_at).to be_present
  end
end
