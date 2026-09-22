require "rails_helper"

RSpec.describe Maintenance::RetentionJob do
  describe "borrado de actividad y análisis (90 días tras el hackathon)" do
    it "borra ActivityEvent y AiAnalysis de un equipo cuyo hackathon terminó hace más de 90 días" do
      team = create(:team)
      team.hackathon.update!(starts_at: 93.days.ago, ends_at: 91.days.ago)
      event = create(:activity_event, team: team)
      analysis = create(:ai_analysis, team: team)

      described_class.new.perform

      expect(ActivityEvent.where(id: event.id).first).to be_nil
      expect(AiAnalysis.where(id: analysis.id).first).to be_nil
    end

    it "no borra nada si el hackathon terminó hace menos de 90 días" do
      team = create(:team)
      team.hackathon.update!(starts_at: 12.days.ago, ends_at: 10.days.ago)
      event = create(:activity_event, team: team)

      described_class.new.perform

      expect(ActivityEvent.where(id: event.id).first).to be_present
    end

    it "no borra nada si el owner marcó retain_data" do
      team = create(:team)
      team.hackathon.update!(starts_at: 93.days.ago, ends_at: 91.days.ago)
      team.update!(settings: team.settings.merge("retain_data" => true))
      event = create(:activity_event, team: team)

      described_class.new.perform

      expect(ActivityEvent.where(id: event.id).first).to be_present
    end

    it "no toca equipos ya borrados lógicamente (los gestiona el borrado físico)" do
      team = create(:team, deleted_at: 1.day.ago)
      team.hackathon.update!(starts_at: 93.days.ago, ends_at: 91.days.ago)
      event = create(:activity_event, team: team)

      described_class.new.perform

      expect(ActivityEvent.where(id: event.id).first).to be_present
    end
  end

  describe "borrado físico de equipos (30 días tras el borrado lógico)" do
    it "borra un equipo marcado como borrado hace más de 30 días" do
      team = create(:team, deleted_at: 31.days.ago)

      described_class.new.perform

      expect(Team.where(id: team.id).first).to be_nil
    end

    it "no borra un equipo borrado hace menos de 30 días" do
      team = create(:team, deleted_at: 5.days.ago)

      described_class.new.perform

      expect(Team.where(id: team.id).first).to be_present
    end
  end
end
