require "rails_helper"

RSpec.describe OutboundWebhook, type: :model do
  it "only accepts HTTPS URLs" do
    webhook = build(:outbound_webhook, url: "http://example.com/hook")

    expect(webhook).not_to be_valid
  end

  it "encrypts the secret and can recover it in plain text" do
    webhook = create(:outbound_webhook, secret: "my-secret")

    expect(webhook.secret_ciphertext).not_to include("my-secret")
    expect(webhook.reload.secret).to eq("my-secret")
  end

  it "does not allow more than 5 webhooks per team" do
    team = create(:team)
    5.times { |n| create(:outbound_webhook, team: team, url: "https://example.com/#{n}") }

    sixth = build(:outbound_webhook, team: team, url: "https://example.com/6")

    expect(sixth).not_to be_valid
  end

  it "pauses itself automatically after 50 failures in a row" do
    webhook = create(:outbound_webhook, consecutive_failures: 50)

    expect(webhook.active).to be false
  end
end
