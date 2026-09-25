# Daily (09-privacidad-seguridad.md#retención). Two independent tasks: 1.
# Deletes ActivityEvent/AiAnalysis of teams whose hackathon ended more than 90
# days ago, unless the owner set settings.retain_data. 2. Physically deletes
# teams soft-deleted (deleted_at) more than 30 days ago. Session (its own TTL)
# and WebhookDelivery (its own TTL) are already cleaned up by Mongo indexes with
# expire_after_seconds.
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
