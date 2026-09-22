require "rails_helper"

RSpec.describe OutboundWebhook, type: :model do
  it "solo acepta URLs HTTPS" do
    webhook = build(:outbound_webhook, url: "http://example.com/hook")

    expect(webhook).not_to be_valid
  end

  it "cifra el secreto y lo puede recuperar en claro" do
    webhook = create(:outbound_webhook, secret: "mi-secreto")

    expect(webhook.secret_ciphertext).not_to include("mi-secreto")
    expect(webhook.reload.secret).to eq("mi-secreto")
  end

  it "no permite más de 5 webhooks por equipo" do
    team = create(:team)
    5.times { |n| create(:outbound_webhook, team: team, url: "https://example.com/#{n}") }

    sixth = build(:outbound_webhook, team: team, url: "https://example.com/6")

    expect(sixth).not_to be_valid
  end

  it "se pausa automáticamente a los 50 fallos consecutivos" do
    webhook = create(:outbound_webhook, consecutive_failures: 50)

    expect(webhook.active).to be false
  end
end
