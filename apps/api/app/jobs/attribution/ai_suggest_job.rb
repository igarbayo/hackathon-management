# Cron cada 10 min por equipo con eventos pendientes (05-atribucion.md#capa-3,
# 01-arquitectura.md#jobs-de-sidekiq).
module Attribution
  class AiSuggestJob
    include Sidekiq::Job
    sidekiq_options queue: "ai", retry: 3

    def perform(team_id = nil)
      if team_id
        team = Team.where(id: team_id).first
        Attribution::SuggestForTeam.call(team) if team
        return
      end

      team_ids_with_pending_events.each { |id| self.class.perform_async(id.to_s) }
    end

    private

    def team_ids_with_pending_events
      ActivityEvent.where(:occurred_at.gte => 24.hours.ago)
                   .any_in(kind: ActivityEvent::ATTRIBUTABLE_KINDS)
                   .any_of({ attribution: nil }, { "attribution.status" => "rejected" })
                   .distinct(:team_id)
    end
  end
end
