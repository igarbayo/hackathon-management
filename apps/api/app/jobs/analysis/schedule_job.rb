# Cron cada minuto (06-analisis-ia.md#disparo): busca equipos cuyo último
# análisis tiene más de settings.analysis_interval_min minutos, dentro de la
# ventana del hackathon (starts_at − 12h a ends_at + 1h). El propio RunJob
# se salta la llamada a la IA si el contexto no cambió (input_hash igual).
module Analysis
  class ScheduleJob
    include Sidekiq::Job
    sidekiq_options queue: "low"

    def perform
      Team.active.each do |team|
        next unless within_hackathon_window?(team)
        next unless due?(team)

        Analysis::Enqueue.call(team: team, trigger: "scheduled")
      end
    end

    private

    def within_hackathon_window?(team)
      hackathon = team.hackathon
      return false unless hackathon&.starts_at && hackathon&.ends_at

      now = Time.current
      now.between?(hackathon.starts_at - 12.hours, hackathon.ends_at + 1.hour)
    end

    def due?(team)
      interval = (team.settings["analysis_interval_min"] || Analysis::Quota.scheduled_interval(team).in_minutes).to_i.minutes
      last = AiAnalysis.where(team_id: team.id).order(created_at: :desc).first

      last.nil? || last.created_at <= Time.current - interval
    end
  end
end
