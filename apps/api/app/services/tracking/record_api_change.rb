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
        actor: actor_hash(membership, resolved_token),
        title: "#{entity} #{key} edited through #{channel == 'mcp' ? 'MCP' : 'API'}",
        payload: { "entity" => entity, "key" => key.to_s, "fields" => fields },
        via: resolved_token.via(channel: channel)
      )
    end

    # With an integration token the actor is the integration itself, not a
    # person (12-acceso-programatico.md#tokens-de-integración-de-equipo).
    def self.actor_hash(membership, resolved_token)
      if membership
        { "user_id" => membership.user_id.to_s, "membership_id" => membership.id.to_s, "display" => membership.display_name }
      else
        token = resolved_token.token_record
        { "user_id" => nil, "membership_id" => nil, "integration_id" => token.id.to_s, "display" => "#{token.name} (integration)" }
      end
    end
  end
end
