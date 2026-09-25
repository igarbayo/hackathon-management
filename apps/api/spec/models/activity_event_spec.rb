require "rails_helper"

RSpec.describe ActivityEvent, type: :model do
  it "does not allow a kind that does not belong to the source" do
    event = build(:activity_event, source: "github", kind: "cc_turn")

    expect(event).not_to be_valid
    expect(event.errors[:kind]).to be_present
  end

  it "accepts a valid kind for claude_code" do
    event = build(:activity_event, :claude_turn)

    expect(event).to be_valid
  end

  it "the dedupe_key is unique per team" do
    team = create(:team)
    create(:activity_event, team: team, dedupe_key: "gh:commit:abc")
    duplicate = build(:activity_event, team: team, dedupe_key: "gh:commit:abc")

    expect(duplicate).not_to be_valid
  end

  it "the same dedupe_key can repeat across different teams" do
    create(:activity_event, dedupe_key: "gh:commit:same")
    other_team_event = build(:activity_event, dedupe_key: "gh:commit:same")

    expect(other_team_event).to be_valid
  end

  it "does not accept more than 50 files" do
    event = build(:activity_event, files: Array.new(51) { { path: "a.rb" } })

    expect(event).not_to be_valid
  end

  describe "embedded attribution" do
    it "requires feature_id except when the status is rejected" do
      event = build(:activity_event)
      event.build_attribution(method: "convention", status: "confirmed")

      expect(event).not_to be_valid
      expect(event.attribution.errors[:feature_id]).to be_present
    end

    it "allows rejected without feature_id" do
      event = build(:activity_event)
      event.build_attribution(method: "ai", status: "rejected", confidence: 0.4)

      expect(event).to be_valid
    end
  end
end
