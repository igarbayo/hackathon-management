require "rails_helper"

RSpec.describe Ingest::ProcessBatch do
  def event(overrides = {})
    {
      "client_event_id" => SecureRandom.hex(8),
      "kind" => "cc_turn",
      "occurred_at" => Time.current.iso8601,
      "session_ref" => "abc123",
      "repo" => { "remote" => "github.com/hackboard/repo" },
      "data" => { "files" => [ { "path" => "a.rb", "tool" => "Edit" } ], "tool_uses" => 2 }
    }.deep_merge(overrides)
  end

  let(:team) { create(:team) }
  let(:membership) do
    create(:membership, team: team).tap do |m|
      m.update!(claude_code_attributes: { token_digest: "d", token_prefix: "hb_mt_ab12", privacy_level: "metadata" })
    end
  end

  before { create(:repository, team: team, remote_urls: [ "github.com/hackboard/repo" ]) }

  it "accepts a valid event from a linked repo and queues the job" do
    result = described_class.call(team: team, membership: membership, cli_version: "0.3.1", events: [ event ])

    expect(result.accepted).to eq(1)
    expect(result.duplicates).to eq(0)
    expect(result.rejected).to be_empty
    expect(Ingest::ProcessBatchJob.jobs.size).to eq(1)
  end

  it "rejects with repo_not_linked if the remote is not linked" do
    result = described_class.call(team: team, membership: membership, cli_version: "0.3.1", events: [ event("repo" => { "remote" => "github.com/other/repo" }) ])

    expect(result.accepted).to eq(0)
    expect(result.rejected.first[:reason]).to eq("repo_not_linked")
  end

  it "rejects with invalid_schema if a required field is missing" do
    bad = event.except("session_ref")

    result = described_class.call(team: team, membership: membership, cli_version: "0.3.1", events: [ bad ])

    expect(result.rejected.first[:reason]).to eq("invalid_schema")
  end

  it "rejects with privacy_off if the member's level is off" do
    membership.claude_code.update!(privacy_level: "off")

    result = described_class.call(team: team, membership: membership, cli_version: "0.3.1", events: [ event ])

    expect(result.rejected.first[:reason]).to eq("privacy_off")
  end

  it "rejects with paused if the link is paused" do
    membership.claude_code.update!(paused: true)

    result = described_class.call(team: team, membership: membership, cli_version: "0.3.1", events: [ event ])

    expect(result.rejected.first[:reason]).to eq("paused")
  end

  it "counts an already processed client_event_id as a duplicate" do
    e = event
    create(:activity_event, team: team, source: "claude_code", kind: "cc_turn", dedupe_key: "cc:#{e['client_event_id']}")

    result = described_class.call(team: team, membership: membership, cli_version: "0.3.1", events: [ e ])

    expect(result.accepted).to eq(0)
    expect(result.duplicates).to eq(1)
  end

  def result_event_id(_result)
    nil
  end
end
