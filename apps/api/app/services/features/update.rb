# RF-FEAT-004: los cambios de status y assignee_ids generan eventos `system`.
# `via` (RF-API-006) solo viene relleno si el cambio lo hizo un token.
module Features
  class Update
    def self.call(feature:, attrs:, via: nil)
      status_changing = attrs.key?("status") && attrs["status"] != feature.status
      assignees_changing = attrs.key?("assignee_ids") && Array(attrs["assignee_ids"]).sort != feature.assignee_ids.map(&:to_s).sort

      previous_status = feature.status
      feature.update!(attrs)

      emit_status_event(feature, previous_status, via) if status_changing
      emit_assignee_event(feature, via) if assignees_changing

      feature
    end

    def self.emit_status_event(feature, previous_status, via)
      ActivityEvent.create!(
        team_id: feature.team_id,
        source: "system",
        kind: "feature_status_changed",
        dedupe_key: "system:feature_status_changed:#{feature.id}:#{feature.updated_at.to_f}",
        occurred_at: Time.current,
        title: "#{feature.key} pasó de #{previous_status} a #{feature.status}",
        payload: { entity: "feature", key: feature.key, action: "status_changed", fields: ["status"] },
        via: via
      )
    end
    private_class_method :emit_status_event

    def self.emit_assignee_event(feature, via)
      ActivityEvent.create!(
        team_id: feature.team_id,
        source: "system",
        kind: "feature_assigned",
        dedupe_key: "system:feature_assigned:#{feature.id}:#{feature.updated_at.to_f}",
        occurred_at: Time.current,
        title: "#{feature.key}: asignación actualizada",
        payload: { entity: "feature", key: feature.key, action: "assigned", fields: ["assignee_ids"] },
        via: via
      )
    end
    private_class_method :emit_assignee_event
  end
end
