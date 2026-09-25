# Creates the ActivityEvents already validated by Ingest::ProcessBatch
# (RF-CC-004). Once created, attribution (layers 1-3) runs by itself through
# ActivityEvent#enqueue_attribution for the kinds in ATTRIBUTABLE_KINDS.
module Ingest
  class ProcessBatchJob
    include Sidekiq::Job
    sidekiq_options queue: "ingest", retry: 5

    def perform(team_id, membership_id, events)
      team = Team.where(id: team_id).first
      membership = Membership.where(id: membership_id).first
      return unless team && membership

      actor = {
        "user_id" => membership.user_id.to_s,
        "membership_id" => membership.id.to_s,
        "display" => membership.display_name,
        "github_login" => nil
      }

      events.each { |event| create_event(team, membership, actor, event) }
    end

    private

    def create_event(team, membership, actor, event)
      dedupe_key = "cc:#{event['client_event_id']}"
      return if ActivityEvent.where(team_id: team.id, dedupe_key: dedupe_key).exists?

      repo = event.dig("repo", "remote") && Repository.where(team_id: team.id, remote_urls: event.dig("repo", "remote")).first
      data = event["data"] || {}
      files = Array(data["files"]).first(ActivityEvent::MAX_FILES).map { |f| { "path" => f["path"], "tool" => f["tool"] } }

      ActivityEvent.create!(
        team_id: team.id,
        source: "claude_code",
        kind: event["kind"],
        dedupe_key: dedupe_key,
        occurred_at: Time.zone.parse(event["occurred_at"]),
        actor: actor,
        repository_id: repo&.id,
        branch: event.dig("repo", "branch"),
        sha: event.dig("repo", "head_sha"),
        session_ref: event["session_ref"],
        files: files,
        title: title_for(event),
        summary: summary_for(membership, data),
        stats: { "tool_uses" => data["tool_uses"], "duration_ms" => data["duration_ms"], "prompt_chars" => data["prompt_chars"] }.compact,
        payload: { "reason" => data["reason"] }.compact
      )
    rescue Mongoid::Errors::Validations
      nil
    end

    def title_for(event)
      case event["kind"]
      when "cc_session_start" then "Claude Code session started"
      when "cc_session_end" then "Claude Code session ended"
      when "cc_turn" then "Claude Code turn"
      when "system_test" then "Claude Code connection test"
      end
    end

    # The turn summary (summaries, RF-CC-… option A) is only stored if the
    # member's level allows it, even though the event already went through
    # Ingest::ProcessBatch with that same level: it is the second barrier.
    def summary_for(membership, data)
      return nil unless membership.claude_code&.privacy_level == "summaries"

      data["summary"]
    end
  end
end
