# Nunca expone el secreto (se muestra una sola vez, al crearlo o rotarlo).
class OutboundWebhookSerializer
  def initialize(webhook)
    @webhook = webhook
  end

  def as_json
    {
      id: webhook.id.to_s,
      url: webhook.url,
      events: webhook.events,
      active: webhook.active,
      consecutive_failures: webhook.consecutive_failures,
      created_by_id: webhook.created_by_id&.to_s,
      created_at: webhook.created_at&.iso8601
    }
  end

  private

  attr_reader :webhook
end
