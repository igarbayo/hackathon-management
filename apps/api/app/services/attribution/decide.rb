# Acción humana sobre la atribución de un evento (RF-ATR-004).
module Attribution
  class Decide
    ACTIONS = %w[confirm reject set unlink].freeze

    class InvalidAction < StandardError; end

    def self.call(event:, action:, decided_by:, feature: nil)
      new(event: event, action: action, decided_by: decided_by, feature: feature).call
    end

    def initialize(event:, action:, decided_by:, feature: nil)
      @event = event
      @action = action
      @decided_by = decided_by
      @feature = feature
    end

    def call
      raise InvalidAction, "acción desconocida: #{action}" unless ACTIONS.include?(action)

      case action
      when "confirm" then confirm
      when "reject" then reject
      when "set" then set_feature
      when "unlink" then unlink
      end

      event.save!
      event
    end

    private

    attr_reader :event, :action, :decided_by, :feature

    def confirm
      current = event.attribution
      raise InvalidAction, "no hay una sugerencia que confirmar" unless current&.feature_id

      current.status = "confirmed"
      current.decided_by_id = decided_by.id
      current.decided_at = Time.current
      learn_branch(Feature.find(current.feature_id))
    end

    def reject
      current = event.attribution
      raise InvalidAction, "no hay una sugerencia que rechazar" unless current&.feature_id

      rejected_id = current.feature_id
      current.status = "rejected"
      current.feature_id = nil
      current.rejected_feature_ids = (current.rejected_feature_ids + [rejected_id]).uniq
      current.decided_by_id = decided_by.id
      current.decided_at = Time.current
    end

    def set_feature
      raise InvalidAction, "hace falta indicar la feature" unless feature

      rejected_ids = event.attribution&.rejected_feature_ids || []
      event.build_attribution(
        feature_id: feature.id,
        method: "manual",
        status: "confirmed",
        decided_by_id: decided_by.id,
        decided_at: Time.current,
        rejected_feature_ids: rejected_ids
      )
      learn_branch(feature)
    end

    # Desvincular deja el evento como "sin atribuir" pero conserva
    # rejected_feature_ids para no volver a sugerir la misma feature
    # (05-atribucion.md#acción-humana). Se modela como un rechazo de la
    # atribución vigente en vez de vaciar el sub-documento entero.
    def unlink
      current = event.attribution
      raise InvalidAction, "el evento no tiene atribución" unless current

      previous_id = current.feature_id
      current.status = "rejected"
      current.feature_id = nil
      current.rejected_feature_ids = previous_id ? (current.rejected_feature_ids + [previous_id]).uniq : current.rejected_feature_ids
      current.decided_by_id = decided_by.id
      current.decided_at = Time.current
    end

    def learn_branch(target_feature)
      Attribution::LearnBranch.call(feature: target_feature, event: event)
    end
  end
end
