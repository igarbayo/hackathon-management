require "rails_helper"

RSpec.describe Github::LinkRepository do
  around do |example|
    original_id = ENV["GITHUB_APP_ID"]
    original_key = ENV["GITHUB_APP_PRIVATE_KEY"]
    original_slug = ENV["GITHUB_APP_SLUG"]
    ENV["GITHUB_APP_ID"] = "1"
    ENV["GITHUB_APP_PRIVATE_KEY"] = OpenSSL::PKey::RSA.generate(2048).to_pem
    ENV["GITHUB_APP_SLUG"] = "hackboard-dev"
    example.run
    ENV["GITHUB_APP_ID"] = original_id
    ENV["GITHUB_APP_PRIVATE_KEY"] = original_key
    ENV["GITHUB_APP_SLUG"] = original_slug
  end

  before do
    stub_request(:post, "https://api.github.com/app/installations/42/access_tokens")
      .to_return(status: 201, body: { token: "ghs_x" }.to_json, headers: { "Content-Type" => "application/json" })
  end

  it "links right away if any of the team's installations already has access" do
    membership = create(:membership)
    team = membership.team
    team.update!(github_installation_ids: [ 42 ])

    stub_request(:get, "https://api.github.com/installation/repositories").with(query: hash_including("per_page" => "100"))
      .to_return(status: 200, body: { repositories: [ { id: 1, full_name: "org/repo", default_branch: "main" } ] }.to_json, headers: { "Content-Type" => "application/json" })

    result = described_class.call(team: team, user: membership.user, full_name: "org/repo")

    expect(result.linked).to be true
    expect(result.repository.full_name).to eq("org/repo")
  end

  it "returns needs_install if no installation has access" do
    membership = create(:membership)
    team = membership.team
    team.update!(github_installation_ids: [ 42 ])

    stub_request(:get, "https://api.github.com/installation/repositories").with(query: hash_including("per_page" => "100"))
      .to_return(status: 200, body: { repositories: [] }.to_json, headers: { "Content-Type" => "application/json" })

    result = described_class.call(team: team, user: membership.user, full_name: "org/repo")

    expect(result.linked).to be false
    expect(result.install_url).to include("github.com/apps/hackboard-dev/installations/new?state=")
  end
end
