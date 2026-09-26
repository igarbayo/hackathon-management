require "rails_helper"

RSpec.describe Analysis::DeterministicAlerts do
  def team_with_hackathon(starts_at: 2.hours.ago, ends_at: 10.hours.from_now)
    create(:team, hackathon: build(:hackathon, starts_at: starts_at, ends_at: ends_at))
  end

  describe "objective_without_features" do
    it "high alert if a must objective has no active features" do
      team = create(:team)
      objective = create(:objective, team: team, priority: "must")

      codes = described_class.call(team)
      expect(codes).to include(a_hash_including("code" => "objective_without_features", "severity" => "high", "related_keys" => [ objective.key ]))
    end

    it "severity medium if the objective is should" do
      team = create(:team)
      create(:objective, team: team, priority: "should")

      alert = described_class.call(team).find { |a| a["code"] == "objective_without_features" }
      expect(alert["severity"]).to eq("medium")
    end

    it "no alert if it has a linked active feature" do
      team = create(:team)
      objective = create(:objective, team: team, priority: "must")
      create(:feature, team: team, objective_ids: [ objective.id ], status: "idea")

      expect(described_class.call(team)).to be_empty
    end

    it "uses objective_without_features_near_end with less than 6h to the end" do
      team = team_with_hackathon(ends_at: 2.hours.from_now)
      objective = create(:objective, team: team, priority: "should")

      alert = described_class.call(team).find { |a| a["related_keys"] == [ objective.key ] }
      expect(alert["code"]).to eq("objective_without_features_near_end")
      expect(alert["severity"]).to eq("high")
    end
  end

  describe "feature_overdue" do
    it "alerts if the deadline passed and it is not done/discarded" do
      team = create(:team)
      feature = create(:feature, team: team, status: "in_progress", deadline: 1.hour.ago)

      expect(described_class.call(team)).to include(a_hash_including("code" => "feature_overdue", "related_keys" => [ feature.key ]))
    end

    it "no alert if it is already done" do
      team = create(:team)
      create(:feature, team: team, status: "done", deadline: 1.hour.ago)

      expect(described_class.call(team).map { |a| a["code"] }).not_to include("feature_overdue")
    end
  end

  describe "feature_unassigned_in_progress" do
    it "medium alert if in_progress with no assignees" do
      team = create(:team)
      feature = create(:feature, team: team, status: "in_progress", assignee_ids: [])

      expect(described_class.call(team)).to include(a_hash_including("code" => "feature_unassigned_in_progress", "severity" => "medium", "related_keys" => [ feature.key ]))
    end
  end

  describe "feature_stale" do
    it "alerts if in_progress with no activity for 3h during the hackathon" do
      team = team_with_hackathon
      feature = create(:feature, team: team, status: "in_progress")

      expect(described_class.call(team)).to include(a_hash_including("code" => "feature_stale", "related_keys" => [ feature.key ]))
    end

    it "no alert outside the hackathon window" do
      team = create(:team, hackathon: build(:hackathon, starts_at: 10.days.ago, ends_at: 9.days.ago))
      create(:feature, team: team, status: "in_progress")

      expect(described_class.call(team).map { |a| a["code"] }).not_to include("feature_stale")
    end
  end

  describe "milestone_soon" do
    it "high alert with a milestone less than 1h away and unfinished must features" do
      team = create(:team)
      objective = create(:objective, team: team, priority: "must")
      feature = create(:feature, team: team, status: "in_progress", objective_ids: [ objective.id ])
      create(:milestone, team: team, due_at: 30.minutes.from_now)

      alert = described_class.call(team).find { |a| a["code"] == "milestone_soon" }
      expect(alert["severity"]).to eq("high")
      expect(alert["related_keys"]).to include(feature.key)
    end

    it "no alert if there are no upcoming milestones" do
      team = create(:team)
      create(:objective, team: team, priority: "must")
      create(:milestone, team: team, due_at: 5.hours.from_now)

      expect(described_class.call(team).map { |a| a["code"] }).not_to include("milestone_soon")
    end
  end

  describe "member_idle" do
    it "low alert if a member has no activity for 4h during the hackathon" do
      team = team_with_hackathon
      membership = create(:membership, team: team)

      alert = described_class.call(team).find { |a| a["code"] == "member_idle" }
      expect(alert["severity"]).to eq("low")
      expect(alert["owners_only"]).to be true
      expect(alert["member"]).to eq(membership.display_name)
    end

    it "no alert for a member with recent activity (actor.user_id is stored as a string)" do
      team = team_with_hackathon
      membership = create(:membership, team: team)
      create(:activity_event, :github_commit, team: team, occurred_at: 10.minutes.ago,
                                              actor: { "user_id" => membership.user_id.to_s, "membership_id" => membership.id.to_s })

      alerts = described_class.call(team).select { |a| a["code"] == "member_idle" }
      expect(alerts).to be_empty
    end
  end
end
