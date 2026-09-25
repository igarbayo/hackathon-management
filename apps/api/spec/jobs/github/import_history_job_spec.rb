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

  def json_headers
    { "Content-Type" => "application/json" }
  end

  def stub_token(repository)
    stub_request(:post, "https://api.github.com/app/installations/#{repository.installation_id}/access_tokens")
      .to_return(status: 201, body: { token: "ghs_x" }.to_json, headers: json_headers)
  end

  def stub_branches(names)
    stub_request(:get, "https://api.github.com/repos/org/repo/branches").with(query: hash_including({}))
      .to_return(status: 200, body: names.map { |n| { "name" => n } }.to_json, headers: json_headers)
  end

  def stub_branch_commits(branch, commits, status: 200)
    stub_request(:get, "https://api.github.com/repos/org/repo/commits").with(query: hash_including("sha" => branch))
      .to_return(status: status, body: commits.to_json, headers: json_headers)
  end

  def stub_open_pulls(pulls = [])
    stub_request(:get, "https://api.github.com/repos/org/repo/pulls").with(query: hash_including("state" => "open"))
      .to_return(status: 200, body: pulls.to_json, headers: json_headers)
  end

  def gh_commit(sha, date: Time.current)
    { "sha" => sha, "html_url" => "u", "author" => { "login" => "octocat" },
      "commit" => { "message" => "commit #{sha}", "author" => { "name" => "Ada", "email" => "a@x.com", "date" => date.iso8601 } } }
  end

  it "importa commits recientes y PRs abiertos" do
    team = create(:team, hackathon: build(:hackathon, starts_at: 2.days.ago))
    repository = create(:repository, team: team, full_name: "org/repo", default_branch: "main")

    stub_request(:post, "https://api.github.com/app/installations/#{repository.installation_id}/access_tokens")
      .to_return(status: 201, body: { token: "ghs_x" }.to_json, headers: { "Content-Type" => "application/json" })
    stub_branches(%w[main])
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
    stub_branches(%w[main])
    stub_request(:get, "https://api.github.com/repos/org/repo/commits").with(query: hash_including({}))
      .to_return(status: 500, body: "{}", headers: { "Content-Type" => "application/json" })

    expect { described_class.new.perform(repository.id.to_s) }.to raise_error(RuntimeError)
    expect(repository.reload.last_import).to include("status" => "failed")
  end

  describe "ramas activas (RF-GH-026)" do
    let(:team) { create(:team, hackathon: build(:hackathon, starts_at: 2.days.ago)) }
    let(:repository) { create(:repository, team: team, full_name: "org/repo", default_branch: "main") }

    before do
      stub_token(repository)
      stub_open_pulls
    end

    it "importa los commits de todas las ramas y guarda en cuáles está cada uno" do
      stub_branches(%w[main f-3-login vieja])
      stub_branch_commits("main", [ gh_commit("merged") ])
      stub_branch_commits("f-3-login", [ gh_commit("merged"), gh_commit("wip") ])
      stub_branch_commits("vieja", [])

      described_class.new.perform(repository.id.to_s)

      merged = ActivityEvent.where(dedupe_key: "gh:commit:merged").first
      expect(merged.branch).to eq("f-3-login")
      expect(merged.branches).to contain_exactly("f-3-login", "main")
      expect(ActivityEvent.where(dedupe_key: "gh:commit:wip").first.branches).to eq([ "f-3-login" ])
      expect(repository.reload.last_import).to include("commits" => 2, "branches" => 2)
    end

    it "añade la rama a un commit ya importado sin duplicarlo" do
      create(:activity_event, :github_commit, team: team, repository: repository, sha: "merged",
                                              dedupe_key: "gh:commit:merged", branch: "f-3-login")
      stub_branches(%w[main])
      stub_branch_commits("main", [ gh_commit("merged") ])

      described_class.new.perform(repository.id.to_s)

      expect(ActivityEvent.where(dedupe_key: "gh:commit:merged").count).to eq(1)
      expect(ActivityEvent.where(dedupe_key: "gh:commit:merged").first.branches).to contain_exactly("f-3-login", "main")
    end

    it "se salta una rama borrada mientras importa" do
      stub_branches(%w[main borrada])
      stub_branch_commits("main", [ gh_commit("a") ])
      stub_branch_commits("borrada", { message: "Not Found" }, status: 404)

      described_class.new.perform(repository.id.to_s)

      expect(repository.reload.last_import).to include("status" => "done", "commits" => 1, "branches" => 1)
    end
  end
end
