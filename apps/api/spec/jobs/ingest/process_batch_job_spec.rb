require "rails_helper"

RSpec.describe Ingest::ProcessBatchJob do
  let(:team) { create(:team) }
  let(:membership) { create(:membership, team: team, display_name: "Ada") }
  let(:repository) { create(:repository, team: team, remote_urls: ["github.com/hackboard/repo"]) }

  it "crea un ActivityEvent cc_turn con actor, ficheros y stats" do
    repository
    event = {
      "client_event_id" => "e1",
      "kind" => "cc_turn",
      "occurred_at" => Time.current.iso8601,
      "session_ref" => "s1",
      "repo" => { "remote" => "github.com/hackboard/repo", "branch" => "f-1", "head_sha" => "abc" },
      "data" => { "files" => [{ "path" => "a.rb", "tool" => "Edit" }], "tool_uses" => 3, "duration_ms" => 100 }
    }

    described_class.new.perform(team.id.to_s, membership.id.to_s, [event])

    created = ActivityEvent.where(team_id: team.id, dedupe_key: "cc:e1").first
    expect(created).to be_present
    expect(created.source).to eq("claude_code")
    expect(created.actor["membership_id"]).to eq(membership.id.to_s)
    expect(created.actor["display"]).to eq("Ada")
    expect(created.repository_id).to eq(repository.id)
    expect(created.branch).to eq("f-1")
    expect(created.files).to eq([{ "path" => "a.rb", "tool" => "Edit" }])
    expect(created.stats["tool_uses"]).to eq(3)
  end

  it "no duplica si ya existe un evento con el mismo dedupe_key" do
    create(:activity_event, team: team, source: "claude_code", kind: "cc_turn", dedupe_key: "cc:e1")
    event = {
      "client_event_id" => "e1", "kind" => "cc_turn", "occurred_at" => Time.current.iso8601,
      "session_ref" => "s1", "repo" => { "remote" => "github.com/hackboard/repo" }, "data" => {}
    }

    expect { described_class.new.perform(team.id.to_s, membership.id.to_s, [event]) }
      .not_to change(ActivityEvent, :count)
  end

  it "solo guarda el summary si el nivel del miembro es summaries" do
    membership.update!(claude_code_attributes: { token_digest: "d", token_prefix: "hb_mt_ab12", privacy_level: "summaries" })
    event = {
      "client_event_id" => "e2", "kind" => "cc_turn", "occurred_at" => Time.current.iso8601,
      "session_ref" => "s1", "repo" => { "remote" => "github.com/hackboard/repo" },
      "data" => { "summary" => "Implementé el login" }
    }

    described_class.new.perform(team.id.to_s, membership.id.to_s, [event])

    expect(ActivityEvent.where(dedupe_key: "cc:e2").first.summary).to eq("Implementé el login")
  end

  it "recorta los ficheros a MAX_FILES para no chocar con la validación del modelo" do
    files = Array.new(60) { |i| { "path" => "f#{i}.rb", "tool" => "Edit" } }
    event = {
      "client_event_id" => "e3", "kind" => "cc_turn", "occurred_at" => Time.current.iso8601,
      "session_ref" => "s1", "repo" => { "remote" => "github.com/hackboard/repo" }, "data" => { "files" => files }
    }

    described_class.new.perform(team.id.to_s, membership.id.to_s, [event])

    expect(ActivityEvent.where(dedupe_key: "cc:e3").first.files.size).to eq(ActivityEvent::MAX_FILES)
  end
end
