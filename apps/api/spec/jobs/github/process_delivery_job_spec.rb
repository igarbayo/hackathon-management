require "rails_helper"

RSpec.describe Github::ProcessDeliveryJob do
  it "ignores the event if there is no active Repository for that github_repo_id" do
    delivery = create(:webhook_delivery, delivery_id: "d1", event: "push")
    payload = { "repository" => { "id" => 999 }, "ref" => "refs/heads/main", "commits" => [] }.to_json

    described_class.new.perform("d1", "push", payload)

    expect(delivery.reload.status).to eq("ignored")
  end

  it "normalizes a push and marks the delivery as processed" do
    team = create(:team)
    repository = create(:repository, team: team, github_repo_id: 555)
    delivery = create(:webhook_delivery, delivery_id: "d2", event: "push")
    payload = {
      "repository" => { "id" => 555 },
      "ref" => "refs/heads/f-1-x",
      "before" => "a", "after" => "b", "forced" => false,
      "commits" => [ { "id" => "sha1", "message" => "something", "timestamp" => Time.current.iso8601, "author" => {} } ],
      "sender" => { "login" => "octocat" }
    }.to_json

    described_class.new.perform("d2", "push", payload)

    expect(delivery.reload.status).to eq("processed")
    expect(ActivityEvent.where(team_id: team.id).count).to eq(1)
  end

  it "installation deleted deactivates that installation's repos" do
    repository = create(:repository, installation_id: 42, active: true)
    payload = { "action" => "deleted", "installation" => { "id" => 42 } }.to_json

    described_class.new.perform("d3", "installation", payload)

    expect(repository.reload.active).to be false
  end
end
