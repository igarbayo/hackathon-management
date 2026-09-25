# Queues one delivery for each active webhook subscribed to `event`
# (12-acceso-programatico.md#webhooks-salientes). claude_code/mcp events never
# get here: the caller decides which events exist.
module Webhooks
  class Enqueue
    def self.call(team:, event:, data:)
      OutboundWebhook.where(team_id: team.id, active: true, events: event).each do |webhook|
        enqueue_for(webhook: webhook, team: team, event: event, data: data)
      end
    end

    def self.enqueue_for(webhook:, team:, event:, data:)
      delivery_id = SecureRandom.uuid
      payload = { id: delivery_id, event: event, occurred_at: Time.current.iso8601, team: { id: team.id.to_s, name: team.name }, data: data }

      delivery = OutboundDelivery.create!(
        team_id: team.id,
        outbound_webhook_id: webhook.id,
        event: event,
        delivery_id: delivery_id,
        status: "pending",
        payload: payload
      )

      Webhooks::DeliverJob.perform_async(delivery.id.to_s)
      delivery
    end
  end
end
