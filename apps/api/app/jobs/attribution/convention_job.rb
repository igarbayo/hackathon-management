# Aplica las capas 1 y 2 (05-atribucion.md) a un evento recién creado.
# Idempotente: si el evento ya tiene attribution, no hace nada.
module Attribution
  class ConventionJob
    include Sidekiq::Job
    sidekiq_options queue: "attribution"

    def perform(event_id)
      event = ActivityEvent.where(id: event_id).first
      return unless event
      return if event.attribution.present?

      convention = Attribution::ApplyConvention.call(event)
      event.set(mentioned_feature_keys: convention.mentioned_keys) if convention.mentioned_keys.present?

      if convention.feature
        event.build_attribution(feature_id: convention.feature.id, method: "convention", status: "confirmed")
        event.save!
        return
      end

      feature = Attribution::ApplyBranch.call(event)
      return unless feature

      event.build_attribution(feature_id: feature.id, method: "branch", status: "confirmed")
      event.save!
    end
  end
end
