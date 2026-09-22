require "rails_helper"

RSpec.describe Github::Client do
  around do |example|
    original_id = ENV["GITHUB_APP_ID"]
    original_key = ENV["GITHUB_APP_PRIVATE_KEY"]
    ENV["GITHUB_APP_ID"] = "12345"
    ENV["GITHUB_APP_PRIVATE_KEY"] = OpenSSL::PKey::RSA.generate(2048).to_pem
    example.run
    ENV["GITHUB_APP_ID"] = original_id
    ENV["GITHUB_APP_PRIVATE_KEY"] = original_key
  end

  before do
    stub_request(:post, "https://api.github.com/app/installations/999/access_tokens")
      .to_return(status: 201, body: { token: "ghs_abc" }.to_json, headers: { "Content-Type" => "application/json" })
  end

  let(:client) { described_class.new(999) }

  it "obtiene el commit con el installation token" do
    stub_request(:get, "https://api.github.com/repos/org/repo/commits/abc123")
      .with(headers: { "Authorization" => "Bearer ghs_abc" })
      .to_return(status: 200, body: { sha: "abc123" }.to_json, headers: { "Content-Type" => "application/json" })

    expect(client.commit("org/repo", "abc123")["sha"]).to eq("abc123")
  end

  it "pagina /installation/repositories hasta que una página viene incompleta" do
    stub_request(:get, "https://api.github.com/installation/repositories")
      .with(query: hash_including({ "page" => "1" }))
      .to_return(status: 200, body: { repositories: Array.new(100) { |i| { id: i } } }.to_json, headers: { "Content-Type" => "application/json" })
    stub_request(:get, "https://api.github.com/installation/repositories")
      .with(query: hash_including({ "page" => "2" }))
      .to_return(status: 200, body: { repositories: [ { id: 100 } ] }.to_json, headers: { "Content-Type" => "application/json" })

    expect(client.repositories.size).to eq(101)
  end

  it "lanza RateLimited si queda menos del 20% del rate limit" do
    stub_request(:get, "https://api.github.com/repos/org/repo/commits/abc123")
      .to_return(
        status: 200, body: { sha: "abc123" }.to_json,
        headers: { "Content-Type" => "application/json", "X-RateLimit-Limit" => "5000", "X-RateLimit-Remaining" => "500", "X-RateLimit-Reset" => (Time.now + 60).to_i.to_s }
      )

    expect { client.commit("org/repo", "abc123") }.to raise_error(Github::Client::RateLimited)
  end

  it "lanza NotFound en un 404" do
    stub_request(:get, "https://api.github.com/repos/org/repo/commits/nope").to_return(status: 404, body: "{}")

    expect { client.commit("org/repo", "nope") }.to raise_error(Github::Client::NotFound)
  end
end
