# RF-FEAT-004: creating a feature records a `system/feature_created` event with
# who created it (`actor`, Tracking::Actor) and, if a token did it, `via`
# (RF-API-006). It lists the fields that were set, not their values.
module Features
  class Create
    def self.call(team:, created_by:, attrs:, actor:, via: nil)
      feature = Feature.new(attrs)
      feature.team = team
      feature.created_by_id = created_by&.id
      feature.save!

      ActivityEvent.create!(
        team_id: team.id,
        source: "system",
        kind: "feature_created",
        dedupe_key: "system:feature_created:#{feature.id}",
        occurred_at: Time.current,
        actor: actor,
        title: "#{feature.key} created",
        payload: { entity: "feature", key: feature.key, action: "created", fields: attrs.keys.map(&:to_s) },
        via: via
      )
      ::Webhooks::Enqueue.call(team: team, event: "feature.created", data: FeatureSerializer.new(feature, detail: true).as_json)
      feature
    end
  end
end
