# It never exposes the response body (02-modelo-datos.md#outbounddelivery).
class OutboundDeliverySerializer
  def initialize(delivery)
    @delivery = delivery
  end

  def as_json
    {
      id: delivery.id.to_s,
      event: delivery.event,
      delivery_id: delivery.delivery_id,
      status: delivery.status,
      attempts: delivery.attempts,
      response_status: delivery.response_status,
      duration_ms: delivery.duration_ms,
      next_attempt_at: delivery.next_attempt_at&.iso8601,
      created_at: delivery.created_at&.iso8601
    }
  end

  private

  attr_reader :delivery
end
