require "rails_helper"

RSpec.describe Ingest::ProcessBatch do
  def event(overrides = {})
    {
      "client_event_id" => SecureRandom.hex(8),
      "kind" => "cc_turn",
      "occurred_at" => Time.current.iso8601,
      "session_ref" => "abc123",
      "repo" => { "remote" => "github.com/hackboard/repo" },
      "data" => { "files" => [{ "path" => "a.rb", "tool" => "Edit" }], "tool_uses" => 2 }
    }.deep_merge(overrides)
  end

  let(:team) { create(:team) }
  let(:membership) do
    create(:membership, team: team).tap do |m|
      m.update!(claude_code_attributes: { token_digest: "d", token_prefix: "hb_mt_ab12", privacy_level: "metadata" })
    end
  end

  before { create(:repository, team: team, remote_urls: ["github.com/hackboard/repo"]) }

  it "acepta un evento válido de un repo vinculado y encola el job" do
    result = described_class.call(team: team, membership: membership, cli_version: "0.3.1", events: [event])

    expect(result.accepted).to eq(1)
    expect(result.duplicates).to eq(0)
    expect(result.rejected).to be_empty
    expect(Ingest::ProcessBatchJob.jobs.size).to eq(1)
  end

  it "rechaza con repo_not_linked si el remote no está vinculado" do
    result = described_class.call(team: team, membership: membership, cli_version: "0.3.1", events: [event("repo" => { "remote" => "github.com/otro/repo" })])

    expect(result.accepted).to eq(0)
    expect(result.rejected.first[:reason]).to eq("repo_not_linked")
  end

  it "rechaza con invalid_schema si falta un campo obligatorio" do
    bad = event.except("session_ref")

    result = described_class.call(team: team, membership: membership, cli_version: "0.3.1", events: [bad])

    expect(result.rejected.first[:reason]).to eq("invalid_schema")
  end

  it "rechaza con privacy_off si el nivel del miembro es off" do
    membership.claude_code.update!(privacy_level: "off")

    result = described_class.call(team: team, membership: membership, cli_version: "0.3.1", events: [event])

    expect(result.rejected.first[:reason]).to eq("privacy_off")
  end

  it "rechaza con paused si el enlace está pausado" do
    membership.claude_code.update!(paused: true)

    result = described_class.call(team: team, membership: membership, cli_version: "0.3.1", events: [event])

    expect(result.rejected.first[:reason]).to eq("paused")
  end

  it "cuenta como duplicado un client_event_id ya procesado" do
    e = event
    create(:activity_event, team: team, source: "claude_code", kind: "cc_turn", dedupe_key: "cc:#{e['client_event_id']}")

    result = described_class.call(team: team, membership: membership, cli_version: "0.3.1", events: [e])

    expect(result.accepted).to eq(0)
    expect(result.duplicates).to eq(1)
  end

  def result_event_id(_result)
    nil
  end
end
