# Diario (09-privacidad-seguridad.md#retención). Dos tareas independientes:
# 1. Borra ActivityEvent/AiAnalysis de equipos cuyo hackathon terminó hace
#    más de 90 días, salvo que el owner haya marcado settings.retain_data.
# 2. Borra físicamente los equipos con borrado lógico (deleted_at) desde
#    hace más de 30 días.
# Session (TTL propio) y WebhookDelivery (TTL propio) ya se limpian solos
# vía índices Mongo con expire_after_seconds.
module Maintenance
  class RetentionJob
    include Sidekiq::Job
    sidekiq_options queue: "default", retry: 3

    ACTIVITY_RETENTION = 90.days
    TEAM_HARD_DELETE_AFTER = 30.days

    def perform
      purge_activity_and_analyses
      hard_delete_teams
    end

    private

    def purge_activity_and_analyses
      Team.active.each do |team|
        next if team.settings["retain_data"]

        ends_at = team.hackathon&.ends_at
        next unless ends_at && ends_at <= ACTIVITY_RETENTION.ago

        ActivityEvent.where(team_id: team.id).delete_all
        AiAnalysis.where(team_id: team.id).delete_all
      end
    end

    def hard_delete_teams
      Team.where(:deleted_at.lte => TEAM_HARD_DELETE_AFTER.ago).destroy_all
    end
  end
end
