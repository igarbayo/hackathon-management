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

  it "imports recent commits and open PRs" do
    team = create(:team, hackathon: build(:hackathon, starts_at: 2.days.ago))
    repository = create(:repository, team: team, full_name: "org/repo", default_branch: "main")

    stub_request(:post, "https://api.github.com/app/installations/#{repository.installation_id}/access_tokens")
      .to_return(status: 201, body: { token: "ghs_x" }.to_json, headers: { "Content-Type" => "application/json" })
    stub_branches(%w[main])
    stub_request(:get, "https://api.github.com/repos/org/repo/commits")
      .with(query: hash_including("sha" => "main"))
      .to_return(status: 200, body: [
        { "sha" => "abc", "html_url" => "u", "author" => { "login" => "octocat" },
          "commit" => { "message" => "something", "author" => { "name" => "Ada", "email" => "a@x.com", "date" => Time.current.iso8601 } } }
      ].to_json, headers: { "Content-Type" => "application/json" })
    stub_request(:get, "https://api.github.com/repos/org/repo/pulls")
      .with(query: hash_including("state" => "open"))
      .to_return(status: 200, body: [
        { "number" => 3, "title" => "Open PR", "created_at" => Time.current.iso8601, "html_url" => "u2",
          "head" => { "ref" => "f-3" }, "user" => { "login" => "octocat" } }
      ].to_json, headers: { "Content-Type" => "application/json" })

    described_class.new.perform(repository.id.to_s)

    expect(ActivityEvent.where(team_id: team.id, kind: "commit").count).to eq(1)
    expect(ActivityEvent.where(team_id: team.id, kind: "pr_opened").count).to eq(1)
    expect(repository.reload.last_import).to include("status" => "done", "commits" => 1, "pull_requests" => 1)
  end

  it "without starts_at it fetches no commits and says so in last_import (RF-GH-025)" do
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

  it "marks the import as failed if GitHub responds with an error" do
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

  describe "stuck imports (RF-GH-025)" do
    it "enqueue marks it as queued with a deadline" do
      repository = create(:repository)
      allow(described_class).to receive(:perform_async)

      described_class.enqueue(repository)

      last_import = repository.reload.last_import
      expect(last_import["status"]).to eq("queued")
      expect(Time.zone.parse(last_import["expires_at"])).to be_within(5.seconds).of(described_class::STALE_AFTER.from_now)
    end

    it "when rate limited, the deadline counts from when the quota comes back" do
      team = create(:team, hackathon: build(:hackathon, starts_at: 2.days.ago))
      repository = create(:repository, team: team, full_name: "org/repo", default_branch: "main")
      reset_at = 40.minutes.from_now.change(usec: 0)
      allow(Github::Client).to receive(:new).and_raise(Github::Client::RateLimited.new(reset_at))
      allow(described_class).to receive(:perform_at)

      described_class.new.perform(repository.id.to_s)

      expect(repository.reload.last_import).to eq(
        "status" => "queued", "expires_at" => (reset_at + described_class::STALE_AFTER).utc.iso8601
      )
      expect(described_class).to have_received(:perform_at).with(reset_at, repository.id.to_s)
    end
  end

  describe "active branches (RF-GH-026)" do
    let(:team) { create(:team, hackathon: build(:hackathon, starts_at: 2.days.ago)) }
    let(:repository) { create(:repository, team: team, full_name: "org/repo", default_branch: "main") }

    before do
      stub_token(repository)
      stub_open_pulls
    end

    it "imports the commits of every branch and stores which ones each commit is on" do
      stub_branches(%w[main f-3-login stale])
      stub_branch_commits("main", [ gh_commit("merged") ])
      stub_branch_commits("f-3-login", [ gh_commit("merged"), gh_commit("wip") ])
      stub_branch_commits("stale", [])

      described_class.new.perform(repository.id.to_s)

      merged = ActivityEvent.where(dedupe_key: "gh:commit:merged").first
      expect(merged.branch).to eq("f-3-login")
      expect(merged.branches).to contain_exactly("f-3-login", "main")
      expect(ActivityEvent.where(dedupe_key: "gh:commit:wip").first.branches).to eq([ "f-3-login" ])
      expect(repository.reload.last_import).to include("commits" => 2, "branches" => 2)
    end

    it "adds the branch to an already imported commit without duplicating it" do
      create(:activity_event, :github_commit, team: team, repository: repository, sha: "merged",
                                              dedupe_key: "gh:commit:merged", branch: "f-3-login")
      stub_branches(%w[main])
      stub_branch_commits("main", [ gh_commit("merged") ])

      described_class.new.perform(repository.id.to_s)

      expect(ActivityEvent.where(dedupe_key: "gh:commit:merged").count).to eq(1)
      expect(ActivityEvent.where(dedupe_key: "gh:commit:merged").first.branches).to contain_exactly("f-3-login", "main")
    end

    it "spreads the stats requests over time (RNF-GH-002)" do
      per_minute = described_class::STATS_PER_MINUTE
      stub_branches(%w[main])
      stub_branch_commits("main", Array.new(per_minute * 2 + 1) { |i| gh_commit("c#{i}", date: i.minutes.ago) })

      started_at = Time.now.to_f
      described_class.new.perform(repository.id.to_s)

      minutes = Github::FetchCommitStatsJob.jobs.map { |job| ((job["at"] || started_at) - started_at) / 60.0 }.map(&:round)
      expect(minutes.tally).to eq(0 => per_minute, 1 => per_minute, 2 => 1)
    end

    it "skips a branch deleted during the import" do
      stub_branches(%w[main deleted])
      stub_branch_commits("main", [ gh_commit("a") ])
      stub_branch_commits("deleted", { message: "Not Found" }, status: 404)

      described_class.new.perform(repository.id.to_s)

      expect(repository.reload.last_import).to include("status" => "done", "commits" => 1, "branches" => 1)
    end
  end
end
