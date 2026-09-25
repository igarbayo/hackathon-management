require "rails_helper"

RSpec.describe Maintenance::RetentionJob do
  describe "deleting activity and analyses (90 days after the hackathon)" do
    it "deletes ActivityEvent and AiAnalysis of a team whose hackathon ended more than 90 days ago" do
      team = create(:team)
      team.hackathon.update!(starts_at: 93.days.ago, ends_at: 91.days.ago)
      event = create(:activity_event, team: team)
      analysis = create(:ai_analysis, team: team)

      described_class.new.perform

      expect(ActivityEvent.where(id: event.id).first).to be_nil
      expect(AiAnalysis.where(id: analysis.id).first).to be_nil
    end

    it "deletes nothing if the hackathon ended less than 90 days ago" do
      team = create(:team)
      team.hackathon.update!(starts_at: 12.days.ago, ends_at: 10.days.ago)
      event = create(:activity_event, team: team)

      described_class.new.perform

      expect(ActivityEvent.where(id: event.id).first).to be_present
    end

    it "deletes nothing if the owner set retain_data" do
      team = create(:team)
      team.hackathon.update!(starts_at: 93.days.ago, ends_at: 91.days.ago)
      team.update!(settings: team.settings.merge("retain_data" => true))
      event = create(:activity_event, team: team)

      described_class.new.perform

      expect(ActivityEvent.where(id: event.id).first).to be_present
    end

    it "does not touch teams already soft-deleted (physical deletion handles them)" do
      team = create(:team, deleted_at: 1.day.ago)
      team.hackathon.update!(starts_at: 93.days.ago, ends_at: 91.days.ago)
      event = create(:activity_event, team: team)

      described_class.new.perform

      expect(ActivityEvent.where(id: event.id).first).to be_present
    end
  end

  describe "physical deletion of teams (30 days after the soft delete)" do
    it "deletes a team marked as deleted more than 30 days ago" do
      team = create(:team, deleted_at: 31.days.ago)

      described_class.new.perform

      expect(Team.where(id: team.id).first).to be_nil
    end

    it "does not delete a team deleted less than 30 days ago" do
      team = create(:team, deleted_at: 5.days.ago)

      described_class.new.perform

      expect(Team.where(id: team.id).first).to be_present
    end
  end
end
