# Fuente de los resúmenes del nivel summaries del CLI (opción A,
# 08-integracion-claude-code.md#cómo-se-generan-los-resúmenes-summaries).
module Mcp
  module Tools
    class ReportProgress
      DAILY_LIMIT_PER_FEATURE = 30
      STATUS_HINTS = %w[started blocked ready_for_review].freeze

      def self.tool_name = "report_progress"
      def self.description = "Informa del progreso en una feature. No cambia su estado: status_hint es solo una sugerencia visible. Llama a esta herramienta al terminar una unidad de trabajo significativa."
      def self.scope = "progress:write"
      def self.read_only? = false

      def self.input_schema
        {
          "type" => "object",
          "required" => %w[feature_key summary],
          "properties" => {
            "feature_key" => { "type" => "string" },
            "summary" => { "type" => "string", "maxLength" => 500 },
            "status_hint" => { "type" => "string", "enum" => STATUS_HINTS }
          },
          "additionalProperties" => false
        }
      end

      def self.call(team:, membership:, resolved_token:, args:)
        raise Mcp::ToolError, "report_progress necesita un token de miembro o PAT de una persona." unless membership

        feature = Mcp::FindFeature.call(team: team, key: args["feature_key"])
        enforce_daily_limit!(team, membership, feature)

        event = ActivityEvent.new(
          team_id: team.id,
          source: "mcp",
          kind: "progress_report",
          dedupe_key: "mcp:progress_report:#{feature.id}:#{SecureRandom.uuid}",
          occurred_at: Time.current,
          actor: { "user_id" => membership.user_id.to_s, "membership_id" => membership.id.to_s, "display" => membership.display_name },
          summary: args["summary"].to_s[0, 500],
          payload: { "status_hint" => args["status_hint"] }.compact,
          via: resolved_token.via(channel: "mcp")
        )
        event.build_attribution(feature_id: feature.id, method: "convention", status: "confirmed")
        event.save!

        { event_id: event.id.to_s, feature_key: feature.key }
      end

      def self.enforce_daily_limit!(team, membership, feature)
        today_start = Time.current.beginning_of_day
        count = ActivityEvent.where(
          team_id: team.id, source: "mcp", kind: "progress_report",
          "actor.membership_id" => membership.id.to_s, "attribution.feature_id" => feature.id,
          :occurred_at.gte => today_start
        ).count

        raise Mcp::ToolError, "Límite diario de #{DAILY_LIMIT_PER_FEATURE} report_progress en #{feature.key} alcanzado." if count >= DAILY_LIMIT_PER_FEATURE
      end
      private_class_method :enforce_daily_limit!
    end
  end
end
