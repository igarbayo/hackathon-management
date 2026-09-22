require "rails_helper"

RSpec.describe Webhooks::MilestoneDueSoonJob do
  it "avisa de un milestone que vence dentro de la próxima hora" do
    team = create(:team)
    create(:outbound_webhook, team: team, events: ["milestone.due_soon"])
    milestone = create(:milestone, team: team, due_at: 30.minutes.from_now)

    described_class.new.perform

    expect(Webhooks::DeliverJob.jobs.size).to eq(1)
    expect(milestone.reload.due_soon_notified_at).to be_present
  end

  it "no avisa dos veces del mismo milestone" do
    team = create(:team)
    create(:outbound_webhook, team: team, events: ["milestone.due_soon"])
    milestone = create(:milestone, team: team, due_at: 30.minutes.from_now, due_soon_notified_at: 5.minutes.ago)

    described_class.new.perform

    expect(Webhooks::DeliverJob.jobs).to be_empty
    expect(milestone.reload.due_soon_notified_at).to be_within(1.second).of(5.minutes.ago)
  end

  it "no avisa de milestones que vencen fuera de la ventana de 1h" do
    team = create(:team)
    create(:outbound_webhook, team: team, events: ["milestone.due_soon"])
    create(:milestone, team: team, due_at: 3.hours.from_now)

    described_class.new.perform

    expect(Webhooks::DeliverJob.jobs).to be_empty
  end

  it "vuelve a avisar si due_at cambia (se limpia due_soon_notified_at)" do
    milestone = create(:milestone, due_at: 2.days.from_now, due_soon_notified_at: 1.hour.ago)

    milestone.update!(due_at: 30.minutes.from_now)

    expect(milestone.due_soon_notified_at).to be_nil
  end
end
