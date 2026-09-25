require "rails_helper"

RSpec.describe Github::ImportHistoryJob do
  around do |example|
    original_id = ENV["GITHUB_APP_ID"]
    original_key = ENV["GITHUB_APP_PRIVATE_KEY"]
    ENV["GITHUB_APP_ID"] = "1"
    ENV["GITHUB_APP_PRIVATE_KEY"] = OpenSSL::PKey::RSA.generate(2048).to_pem
    example.run
    ENV["GITHUB_APP_ID"] = original_id
    ENV["GITHUB_APP_PRIVATE_KEY"] = original_key
  end

  it "importa commits recientes y PRs abiertos" do
    team = create(:team, hackathon: build(:hackathon, starts_at: 2.days.ago))
    repository = create(:repository, team: team, full_name: "org/repo", default_branch: "main")

    stub_request(:post, "https://api.github.com/app/installations/#{repository.installation_id}/access_tokens")
      .to_return(status: 201, body: { token: "ghs_x" }.to_json, headers: { "Content-Type" => "application/json" })
    stub_request(:get, "https://api.github.com/repos/org/repo/commits")
      .with(query: hash_including("sha" => "main"))
      .to_return(status: 200, body: [
        { "sha" => "abc", "html_url" => "u", "author" => { "login" => "octocat" },
          "commit" => { "message" => "algo", "author" => { "name" => "Ada", "email" => "a@x.com", "date" => Time.current.iso8601 } } }
      ].to_json, headers: { "Content-Type" => "application/json" })
    stub_request(:get, "https://api.github.com/repos/org/repo/pulls")
      .with(query: hash_including("state" => "open"))
      .to_return(status: 200, body: [
        { "number" => 3, "title" => "PR abierto", "created_at" => Time.current.iso8601, "html_url" => "u2",
          "head" => { "ref" => "f-3" }, "user" => { "login" => "octocat" } }
      ].to_json, headers: { "Content-Type" => "application/json" })

    described_class.new.perform(repository.id.to_s)

    expect(ActivityEvent.where(team_id: team.id, kind: "commit").count).to eq(1)
    expect(ActivityEvent.where(team_id: team.id, kind: "pr_opened").count).to eq(1)
    expect(repository.reload.last_import).to include("status" => "done", "commits" => 1, "pull_requests" => 1)
  end

  it "sin starts_at no pide commits y lo dice en last_import (RF-GH-025)" do
    team = create(:team, hackathon: build(:hackathon, starts_at: nil))
    repository = create(:repository, team: team, full_name: "org/repo", default_branch: "main")

    stub_request(:post, "https://api.github.com/app/installations/#{repository.installation_id}/access_tokens")
      .to_return(status: 201, body: { token: "ghs_x" }.to_json, headers: { "Content-Type" => "application/json" })
    stub_request(:get, "https://api.github.com/repos/org/repo/pulls")
      .with(query: hash_including("state" => "open"))
      .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })

    described_class.new.perform(repository.id.to_s)

    expect(repository.reload.last_import).to include("status" => "done", "commits" => 0, "pull_requests" => 0, "reason" => "no_starts_at")
  end

  it "marca la importación como fallida si GitHub responde con error" do
    team = create(:team, hackathon: build(:hackathon, starts_at: 2.days.ago))
    repository = create(:repository, team: team, full_name: "org/repo", default_branch: "main")

    stub_request(:post, "https://api.github.com/app/installations/#{repository.installation_id}/access_tokens")
      .to_return(status: 201, body: { token: "ghs_x" }.to_json, headers: { "Content-Type" => "application/json" })
    stub_request(:get, "https://api.github.com/repos/org/repo/commits").with(query: hash_including({}))
      .to_return(status: 500, body: "{}", headers: { "Content-Type" => "application/json" })

    expect { described_class.new.perform(repository.id.to_s) }.to raise_error(RuntimeError)
    expect(repository.reload.last_import).to include("status" => "failed")
  end
end
