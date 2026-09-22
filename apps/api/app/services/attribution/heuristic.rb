# Heurística previa sin IA (05-atribucion.md#capa-3): si el actor solo tiene
# una feature in_progress asignada y el evento no está en la rama por
# defecto, se sugiere esa feature sin gastar tokens.
module Attribution
  class Heuristic
    CONFIDENCE = 0.6
    REASON = "única feature en curso del autor"

    def self.call(team:, group:)
      user_id = group.events.first.actor["user_id"]
      return nil if user_id.blank?
      return nil if on_default_branch?(group)

      in_progress = Feature.where(team_id: team.id, status: "in_progress", assignee_ids: BSON::ObjectId.from_string(user_id)).to_a
      return nil unless in_progress.size == 1

      feature = in_progress.first
      return nil if group.rejected_feature_ids.include?(feature.id)

      { feature: feature, confidence: CONFIDENCE, reason: REASON }
    end

    def self.on_default_branch?(group)
      event = group.events.first
      return false if event.branch.blank?

      event.repository.present? && event.repository.default_branch == event.branch
    end
  end
end
