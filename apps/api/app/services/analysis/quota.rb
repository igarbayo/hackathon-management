# Quotas per plan (06-analisis-ia.md#cuotas). The daily token cap is still
# [ABIERTO] in the spec (to be tuned in F4): it is not implemented here.
module Analysis
  class Quota
    SCHEDULED_INTERVAL_MIN = { "free" => 60, "pro" => 15 }.freeze
    MANUAL_DAILY_LIMIT = { "free" => 5, "pro" => 30 }.freeze

    class ExceededError < StandardError
      attr_reader :retry_after

      def initialize(retry_after)
        @retry_after = retry_after
        super("manual analysis quota exceeded")
      end
    end

    def self.scheduled_interval(team)
      SCHEDULED_INTERVAL_MIN.fetch(team.plan, SCHEDULED_INTERVAL_MIN["free"]).minutes
    end

    def self.manual_limit(team)
      MANUAL_DAILY_LIMIT.fetch(team.plan, MANUAL_DAILY_LIMIT["free"])
    end

    # @raise [ExceededError] if today's manual quota is already used up.
    def self.check_manual!(team)
      today_start = Time.current.beginning_of_day
      count = AiAnalysis.where(team_id: team.id, trigger: "manual", :created_at.gte => today_start).count

      return if count < manual_limit(team)

      raise ExceededError, Time.current.end_of_day - Time.current
    end
  end
end
