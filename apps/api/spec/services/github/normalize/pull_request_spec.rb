require "rails_helper"

RSpec.describe Github::Normalize::PullRequest do
  let(:team) { create(:team) }
  let(:repository) { create(:repository, team: team) }

  def pr_payload(action:, merged: false, number: 7)
    {
      "action" => action,
      "pull_request" => {
        "number" => number, "title" => "Add login", "merged" => merged,
        "head" => { "ref" => "f-12-login" }, "user" => { "login" => "octocat" },
        "html_url" => "https://github.com/org/repo/pull/#{number}",
        "created_at" => Time.current.iso8601, "updated_at" => Time.current.iso8601
      }
    }
  end

  it "opened -> pr_opened" do
    expect(Github::FetchPullRequestFilesJob).to receive(:perform_async)
    described_class.call(team: team, repository: repository, payload: pr_payload(action: "opened"))

    expect(ActivityEvent.first.kind).to eq("pr_opened")
  end

  it "closed with merged true -> pr_merged" do
    allow(Github::FetchPullRequestFilesJob).to receive(:perform_async)
    described_class.call(team: team, repository: repository, payload: pr_payload(action: "closed", merged: true))

    expect(ActivityEvent.first.kind).to eq("pr_merged")
  end

  it "closed without merge -> pr_closed" do
    allow(Github::FetchPullRequestFilesJob).to receive(:perform_async)
    described_class.call(team: team, repository: repository, payload: pr_payload(action: "closed", merged: false))

    expect(ActivityEvent.first.kind).to eq("pr_closed")
  end

  it "is idempotent by number and kind" do
    allow(Github::FetchPullRequestFilesJob).to receive(:perform_async)
    payload = pr_payload(action: "opened")

    described_class.call(team: team, repository: repository, payload: payload)
    described_class.call(team: team, repository: repository, payload: payload)

    expect(ActivityEvent.count).to eq(1)
  end
end
