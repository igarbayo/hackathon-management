require "rails_helper"

RSpec.describe Webhooks::Enqueue do
  it "creates a delivery and queues DeliverJob for each active webhook subscribed to the event" do
    team = create(:team)
    webhook = create(:outbound_webhook, team: team, events: [ "feature.created" ])
    create(:outbound_webhook, team: team, events: [ "objective.created" ])

    described_class.call(team: team, event: "feature.created", data: { key: "F-1" })

    expect(OutboundDelivery.where(outbound_webhook_id: webhook.id, event: "feature.created").count).to eq(1)
    expect(Webhooks::DeliverJob.jobs.size).to eq(1)
  end

  it "queues nothing if the webhook is paused" do
    team = create(:team)
    create(:outbound_webhook, team: team, events: [ "feature.created" ], active: false)

    described_class.call(team: team, event: "feature.created", data: {})

    expect(Webhooks::DeliverJob.jobs).to be_empty
  end

  it "stores the exact payload that will be sent" do
    team = create(:team)
    create(:outbound_webhook, team: team, events: [ "ping" ])

    described_class.call(team: team, event: "ping", data: { message: "hello" })

    delivery = OutboundDelivery.last
    expect(delivery.payload["event"]).to eq("ping")
    expect(delivery.payload["data"]).to eq({ "message" => "hello" })
    expect(delivery.payload["team"]["id"]).to eq(team.id.to_s)
  end
end
