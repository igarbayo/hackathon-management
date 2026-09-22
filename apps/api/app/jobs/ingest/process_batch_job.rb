# Crea los ActivityEvent ya validados por Ingest::ProcessBatch (RF-CC-004).
# Tras crearse, la atribución (capas 1-3) corre sola vía
# ActivityEvent#enqueue_attribution para los kinds de ATTRIBUTABLE_KINDS.
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
      when "cc_session_start" then "Sesión de Claude Code iniciada"
      when "cc_session_end" then "Sesión de Claude Code finalizada"
      when "cc_turn" then "Turno de Claude Code"
      when "system_test" then "Prueba de conexión de Claude Code"
      end
    end

    # El resumen del turno (summaries, RF-CC-… opción A) solo se persiste si
    # el nivel del miembro lo permite, aunque el evento ya haya pasado por
    # Ingest::ProcessBatch con ese mismo nivel: es la segunda barrera.
    def summary_for(membership, data)
      return nil unless membership.claude_code&.privacy_level == "summaries"

      data["summary"]
    end
  end
end
