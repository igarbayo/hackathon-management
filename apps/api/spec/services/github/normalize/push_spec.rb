require "rails_helper"

RSpec.describe Github::Normalize::Push do
  let(:team) { create(:team) }
  let(:repository) { create(:repository, team: team, full_name: "org/repo", default_branch: "main") }

  def push_payload(ref: "refs/heads/f-12-login", commits:, forced: false, before: "a", after: "b")
    { "ref" => ref, "before" => before, "after" => after, "forced" => forced, "commits" => commits, "sender" => { "login" => "octocat" } }
  end

  def commit(sha, message: "something", username: nil, email: "a@example.com", name: "Author")
    { "id" => sha, "message" => message, "timestamp" => Time.current.iso8601, "url" => "https://github.com/org/repo/commit/#{sha}",
      "author" => { "username" => username, "email" => email, "name" => name } }
  end

  it "creates one commit ActivityEvent for each commit in the push" do
    payload = push_payload(commits: [ commit("sha1"), commit("sha2") ])

    described_class.call(team: team, repository: repository, payload: payload)

    expect(ActivityEvent.where(team_id: team.id, kind: "commit").count).to eq(2)
    event = ActivityEvent.where(dedupe_key: "gh:commit:sha1").first
    expect(event.branch).to eq("f-12-login")
    expect(event.title).to eq("something")
  end

  it "ignores tag pushes" do
    payload = push_payload(ref: "refs/tags/v1.0.0", commits: [ commit("sha1") ])

    described_class.call(team: team, repository: repository, payload: payload)

    expect(ActivityEvent.count).to eq(0)
  end

  it "ignores merge commits on the default branch (they are already there as pr_merged)" do
    payload = push_payload(ref: "refs/heads/main", commits: [ commit("sha1", message: "Merge pull request #4 from org/f-4") ])

    described_class.call(team: team, repository: repository, payload: payload)

    expect(ActivityEvent.count).to eq(0)
  end

  it "on a forced push only records the new head" do
    payload = push_payload(forced: true, commits: [ commit("sha1"), commit("sha2") ])
    payload["head_commit"] = commit("sha2")

    described_class.call(team: team, repository: repository, payload: payload)

    expect(ActivityEvent.count).to eq(1)
    expect(ActivityEvent.first.sha).to eq("sha2")
  end

  it "is idempotent by sha" do
    payload = push_payload(commits: [ commit("sha1") ])

    described_class.call(team: team, repository: repository, payload: payload)
    described_class.call(team: team, repository: repository, payload: payload)

    expect(ActivityEvent.count).to eq(1)
  end

  it "queues FetchCommitStatsJob for each commit created" do
    payload = push_payload(commits: [ commit("sha1") ])

    expect(Github::FetchCommitStatsJob).to receive(:perform_async).with(team.id.to_s, repository.id.to_s, "sha1")

    described_class.call(team: team, repository: repository, payload: payload)
  end
end
