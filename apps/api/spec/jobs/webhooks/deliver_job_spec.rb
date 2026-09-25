require "rails_helper"

RSpec.describe Webhooks::DeliverJob do
  before do
    allow(Resolv).to receive(:getaddresses).and_return([ "93.184.216.34" ])
  end

  it "sends the right signature and marks the delivery as succeeded on a 2xx" do
    webhook = create(:outbound_webhook, url: "https://example.com/hook", secret: "s3cr3t")
    delivery = create(:outbound_delivery, team: webhook.team, outbound_webhook: webhook, payload: { "event" => "ping", "id" => "d1" })

    stub = stub_request(:post, "https://example.com/hook").to_return(status: 200, body: "ok")

    described_class.new.perform(delivery.id.to_s)

    expect(stub).to have_been_requested
    delivery.reload
    expect(delivery.status).to eq("succeeded")
    expect(delivery.response_status).to eq(200)
    expect(delivery.attempts).to eq(1)
  end

  it "signs with HMAC-SHA256 over timestamp.body" do
    webhook = create(:outbound_webhook, url: "https://example.com/hook", secret: "s3cr3t")
    delivery = create(:outbound_delivery, team: webhook.team, outbound_webhook: webhook, payload: { "event" => "ping", "id" => "d1" })

    stub_request(:post, "https://example.com/hook").to_return(status: 200) do |request|
      timestamp = request.headers["X-Hackboard-Timestamp"]
      expected = Webhooks::Sign.signature(secret: "s3cr3t", timestamp: timestamp, body: request.body)
      expect(request.headers["X-Hackboard-Signature-256"]).to eq(expected)
      { status: 200 }
    end

    described_class.new.perform(delivery.id.to_s)
  end

  it "resets consecutive_failures to 0 after a success" do
    webhook = create(:outbound_webhook, url: "https://example.com/hook", consecutive_failures: 5)
    delivery = create(:outbound_delivery, team: webhook.team, outbound_webhook: webhook, payload: { "event" => "ping", "id" => "d1" })
    stub_request(:post, "https://example.com/hook").to_return(status: 200)

    described_class.new.perform(delivery.id.to_s)

    expect(webhook.reload.consecutive_failures).to eq(0)
  end

  it "retries if the response is not 2xx, and schedules the next attempt" do
    webhook = create(:outbound_webhook, url: "https://example.com/hook")
    delivery = create(:outbound_delivery, team: webhook.team, outbound_webhook: webhook, payload: { "event" => "ping", "id" => "d1" })
    stub_request(:post, "https://example.com/hook").to_return(status: 500)

    described_class.new.perform(delivery.id.to_s)

    delivery.reload
    expect(delivery.status).to eq("pending")
    expect(delivery.next_attempt_at).to be_present
    expect(webhook.reload.consecutive_failures).to eq(1)
    expect(Webhooks::DeliverJob.jobs.size).to eq(1)
  end

  it "does not retry once 24h have passed since the delivery was created" do
    webhook = create(:outbound_webhook, url: "https://example.com/hook")
    delivery = create(:outbound_delivery, team: webhook.team, outbound_webhook: webhook, payload: { "event" => "ping", "id" => "d1" })
    delivery.set(created_at: 25.hours.ago)
    stub_request(:post, "https://example.com/hook").to_return(status: 500)

    described_class.new.perform(delivery.id.to_s, 5)

    expect(Webhooks::DeliverJob.jobs).to be_empty
  end

  it "pauses the webhook after 50 failures in a row" do
    webhook = create(:outbound_webhook, url: "https://example.com/hook", consecutive_failures: 49)
    delivery = create(:outbound_delivery, team: webhook.team, outbound_webhook: webhook, payload: { "event" => "ping", "id" => "d1" })
    stub_request(:post, "https://example.com/hook").to_return(status: 500)

    described_class.new.perform(delivery.id.to_s)

    expect(webhook.reload.active).to be false
  end

  it "blocks the send for SSRF and does not retry it" do
    allow(Resolv).to receive(:getaddresses).and_return([ "10.0.0.5" ])
    webhook = create(:outbound_webhook, url: "https://internal.example.com/hook")
    delivery = create(:outbound_delivery, team: webhook.team, outbound_webhook: webhook, payload: { "event" => "ping", "id" => "d1" })

    described_class.new.perform(delivery.id.to_s)

    expect(delivery.reload.status).to eq("failed")
    expect(Webhooks::DeliverJob.jobs).to be_empty
  end

  it "does nothing if the webhook is already paused" do
    webhook = create(:outbound_webhook, url: "https://example.com/hook", active: false)
    delivery = create(:outbound_delivery, team: webhook.team, outbound_webhook: webhook, payload: { "event" => "ping", "id" => "d1" })

    described_class.new.perform(delivery.id.to_s)

    expect(delivery.reload.status).to eq("pending")
    expect(a_request(:post, "https://example.com/hook")).not_to have_been_made
  end
end
