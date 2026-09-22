require "rails_helper"

RSpec.describe Attribution::AiSuggestJob do
  it "sin team_id, encola un job por cada equipo con eventos pendientes en las últimas 24h" do
    team_with_pending = create(:team)
    create(:activity_event, :github_commit, team: team_with_pending)

    team_without_pending = create(:team)
    old_event = create(:activity_event, :github_commit, team: team_without_pending, occurred_at: 2.days.ago)
    old_event.build_attribution(feature_id: create(:feature, team: team_without_pending).id, method: "manual", status: "confirmed")
    old_event.save!

    described_class.new.perform

    expect(described_class.jobs.map { |j| j["args"] }).to contain_exactly([ team_with_pending.id.to_s ])
  end

  it "con team_id, delega en Attribution::SuggestForTeam" do
    team = create(:team)

    expect(Attribution::SuggestForTeam).to receive(:call).with(team)

    described_class.new.perform(team.id.to_s)
  end
end
