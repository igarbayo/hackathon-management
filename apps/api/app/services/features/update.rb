# RF-FEAT-004: status and assignee_ids changes create `system` events. `via`
# (RF-API-006) is only set if a token made the change; `actor`
# (Tracking::Actor) is who made it, so the feed does not show "Someone".
module Features
  class Update
    def self.call(feature:, attrs:, via: nil, actor: {})
      status_changing = attrs.key?("status") && attrs["status"] != feature.status
      assignees_changing = attrs.key?("assignee_ids") && Array(attrs["assignee_ids"]).sort != feature.assignee_ids.map(&:to_s).sort

      previous_status = feature.status
      feature.update!(attrs)

      emit_status_event(feature, previous_status, via, actor) if status_changing
      emit_assignee_event(feature, via, actor) if assignees_changing
      ::Webhooks::Enqueue.call(team: feature.team, event: "feature.updated", data: FeatureSerializer.new(feature, detail: true).as_json)

      feature
    end

    def self.emit_status_event(feature, previous_status, via, actor)
      ActivityEvent.create!(
        team_id: feature.team_id,
        source: "system",
        kind: "feature_status_changed",
        dedupe_key: "system:feature_status_changed:#{feature.id}:#{feature.updated_at.to_f}",
        occurred_at: Time.current,
        actor: actor,
        title: "#{feature.key} moved from #{previous_status} to #{feature.status}",
        payload: { entity: "feature", key: feature.key, action: "status_changed", fields: [ "status" ] },
        via: via
      )
      ::Webhooks::Enqueue.call(team: feature.team, event: "feature.status_changed", data: FeatureSerializer.new(feature, detail: true).as_json)
    end
    private_class_method :emit_status_event

    def self.emit_assignee_event(feature, via, actor)
      ActivityEvent.create!(
        team_id: feature.team_id,
        source: "system",
        kind: "feature_assigned",
        dedupe_key: "system:feature_assigned:#{feature.id}:#{feature.updated_at.to_f}",
        occurred_at: Time.current,
        actor: actor,
        title: "#{feature.key}: assignees updated",
        payload: { entity: "feature", key: feature.key, action: "assigned", fields: [ "assignee_ids" ] },
        via: via
      )
      ::Webhooks::Enqueue.call(team: feature.team, event: "feature.assigned", data: FeatureSerializer.new(feature, detail: true).as_json)
    end
    private_class_method :emit_assignee_event
  end
end
