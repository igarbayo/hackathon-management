# Cuotas por plan (06-analisis-ia.md#cuotas). El tope de tokens diario queda
# [ABIERTO] en la spec (a calibrar en F4): no se implementa aquí.
module Analysis
  class Quota
    SCHEDULED_INTERVAL_MIN = { "free" => 60, "pro" => 15 }.freeze
    MANUAL_DAILY_LIMIT = { "free" => 5, "pro" => 30 }.freeze

    class ExceededError < StandardError
      attr_reader :retry_after

      def initialize(retry_after)
        @retry_after = retry_after
        super("cuota de análisis manuales superada")
      end
    end

    def self.scheduled_interval(team)
      SCHEDULED_INTERVAL_MIN.fetch(team.plan, SCHEDULED_INTERVAL_MIN["free"]).minutes
    end

    def self.manual_limit(team)
      MANUAL_DAILY_LIMIT.fetch(team.plan, MANUAL_DAILY_LIMIT["free"])
    end

    # @raise [ExceededError] si ya se agotó la cuota manual de hoy.
    def self.check_manual!(team)
      today_start = Time.current.beginning_of_day
      count = AiAnalysis.where(team_id: team.id, trigger: "manual", :created_at.gte => today_start).count

      return if count < manual_limit(team)

      raise ExceededError, Time.current.end_of_day - Time.current
    end
  end
end
