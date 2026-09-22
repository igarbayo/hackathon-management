require "rails_helper"

RSpec.describe Github::InstallationToken do
  around do |example|
    original_id = ENV["GITHUB_APP_ID"]
    original_key = ENV["GITHUB_APP_PRIVATE_KEY"]
    ENV["GITHUB_APP_ID"] = "12345"
    ENV["GITHUB_APP_PRIVATE_KEY"] = OpenSSL::PKey::RSA.generate(2048).to_pem
    example.run
    ENV["GITHUB_APP_ID"] = original_id
    ENV["GITHUB_APP_PRIVATE_KEY"] = original_key
  end

  it "pide un token nuevo y lo cachea" do
    stub = stub_request(:post, "https://api.github.com/app/installations/999/access_tokens")
           .to_return(status: 201, body: { token: "ghs_abc123" }.to_json, headers: { "Content-Type" => "application/json" })

    token = described_class.fetch(999)

    expect(token).to eq("ghs_abc123")
    expect(stub).to have_been_requested.once

    described_class.fetch(999)
    expect(stub).to have_been_requested.once # segunda vez usa la caché
  end
end
