require "rails_helper"

RSpec.describe Github::Normalize::Push do
  let(:team) { create(:team) }
  let(:repository) { create(:repository, team: team, full_name: "org/repo", default_branch: "main") }

  def push_payload(ref: "refs/heads/f-12-login", commits:, forced: false, before: "a", after: "b")
    { "ref" => ref, "before" => before, "after" => after, "forced" => forced, "commits" => commits, "sender" => { "login" => "octocat" } }
  end

  def commit(sha, message: "algo", username: nil, email: "a@example.com", name: "Autor")
    { "id" => sha, "message" => message, "timestamp" => Time.current.iso8601, "url" => "https://github.com/org/repo/commit/#{sha}",
      "author" => { "username" => username, "email" => email, "name" => name } }
  end

  it "crea un ActivityEvent commit por cada commit del push" do
    payload = push_payload(commits: [ commit("sha1"), commit("sha2") ])

    described_class.call(team: team, repository: repository, payload: payload)

    expect(ActivityEvent.where(team_id: team.id, kind: "commit").count).to eq(2)
    event = ActivityEvent.where(dedupe_key: "gh:commit:sha1").first
    expect(event.branch).to eq("f-12-login")
    expect(event.title).to eq("algo")
  end

  it "si el commit ya estaba en otra rama, solo anota la rama nueva (RF-GH-026)" do
    described_class.call(team: team, repository: repository, payload: push_payload(commits: [ commit("sha1") ]))
    described_class.call(team: team, repository: repository, payload: push_payload(ref: "refs/heads/main", commits: [ commit("sha1") ]))

    events = ActivityEvent.where(dedupe_key: "gh:commit:sha1")
    expect(events.count).to eq(1)
    expect(events.first.branch).to eq("f-12-login")
    expect(events.first.branches).to contain_exactly("f-12-login", "main")
  end

  it "ignora los pushes de tags" do
    payload = push_payload(ref: "refs/tags/v1.0.0", commits: [ commit("sha1") ])

    described_class.call(team: team, repository: repository, payload: payload)

    expect(ActivityEvent.count).to eq(0)
  end

  it "ignora los merge commits de la rama por defecto (ya están como pr_merged)" do
    payload = push_payload(ref: "refs/heads/main", commits: [ commit("sha1", message: "Merge pull request #4 from org/f-4") ])

    described_class.call(team: team, repository: repository, payload: payload)

    expect(ActivityEvent.count).to eq(0)
  end

  it "en un push forced solo registra la cabecera nueva" do
    payload = push_payload(forced: true, commits: [ commit("sha1"), commit("sha2") ])
    payload["head_commit"] = commit("sha2")

    described_class.call(team: team, repository: repository, payload: payload)

    expect(ActivityEvent.count).to eq(1)
    expect(ActivityEvent.first.sha).to eq("sha2")
  end

  it "es idempotente por sha" do
    payload = push_payload(commits: [ commit("sha1") ])

    described_class.call(team: team, repository: repository, payload: payload)
    described_class.call(team: team, repository: repository, payload: payload)

    expect(ActivityEvent.count).to eq(1)
  end

  it "encola FetchCommitStatsJob por cada commit creado" do
    payload = push_payload(commits: [ commit("sha1") ])

    expect(Github::FetchCommitStatsJob).to receive(:perform_async).with(team.id.to_s, repository.id.to_s, "sha1")

    described_class.call(team: team, repository: repository, payload: payload)
  end
end
