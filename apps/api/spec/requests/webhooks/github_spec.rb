require "rails_helper"

RSpec.describe "Webhooks::Github", type: :request do
  around do |example|
    original = ENV["GITHUB_WEBHOOK_SECRET"]
    ENV["GITHUB_WEBHOOK_SECRET"] = "test-secret"
    example.run
    ENV["GITHUB_WEBHOOK_SECRET"] = original
  end

  def signed_headers(body)
    signature = "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", "test-secret", body)
    { "X-Hub-Signature-256" => signature, "X-GitHub-Delivery" => SecureRandom.uuid, "X-GitHub-Event" => "push", "CONTENT_TYPE" => "application/json" }
  end

  it "401 con firma inválida" do
    body = { repository: { id: 1 } }.to_json

    post "/api/v1/webhooks/github", params: body, headers: { "X-Hub-Signature-256" => "sha256=nope", "X-GitHub-Event" => "push", "X-GitHub-Delivery" => "x" }

    expect(response).to have_http_status(:unauthorized)
  end

  it "202 y encola el job con firma válida" do
    body = { repository: { id: 1 }, ref: "refs/heads/main", commits: [] }.to_json
    headers = signed_headers(body)

    expect(Github::ProcessDeliveryJob).to receive(:perform_async)

    post "/api/v1/webhooks/github", params: body, headers: headers

    expect(response).to have_http_status(:accepted)
    expect(WebhookDelivery.where(delivery_id: headers["X-GitHub-Delivery"]).first.status).to eq("received")
  end

  it "200 e ignora una entrega repetida (mismo X-GitHub-Delivery)" do
    body = { repository: { id: 1 } }.to_json
    headers = signed_headers(body)
    create(:webhook_delivery, delivery_id: headers["X-GitHub-Delivery"])

    expect(Github::ProcessDeliveryJob).not_to receive(:perform_async)

    post "/api/v1/webhooks/github", params: body, headers: headers

    expect(response).to have_http_status(:ok)
  end
end
