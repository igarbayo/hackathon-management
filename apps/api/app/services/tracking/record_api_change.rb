# RF-API-006: if a write made with a token (API or MCP) does not already create
# its own event (feature_status_changed, feature_assigned…), it is recorded with
# system/api_change and the list of fields, not their values. It is only called
# when there is a token (web app writes have no via).
module Tracking
  class RecordApiChange
    def self.call(team:, membership:, resolved_token:, entity:, key:, fields:, channel:)
      return if fields.blank?

      ActivityEvent.create!(
        team_id: team.id,
        source: "system",
        kind: "api_change",
        dedupe_key: "api:#{SecureRandom.uuid}",
        occurred_at: Time.current,
        actor: Tracking::Actor.for(membership: membership, resolved_token: resolved_token),
        title: "#{entity} #{key} edited through #{channel == 'mcp' ? 'MCP' : 'API'}",
        payload: { "entity" => entity, "key" => key.to_s, "fields" => fields },
        via: resolved_token.via(channel: channel)
      )
    end
  end
end
