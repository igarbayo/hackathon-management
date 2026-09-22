# Entrega de un webhook saliente (12-acceso-programatico.md#webhooks-salientes).
# Retry propio (no el de Sidekiq) para poder limitar el reintento a 24h en
# total y contar fallos por entrega, no por intento HTTP. El cuerpo vive en
# delivery.payload, no en los argumentos del job, para poder reintentar o
# reenviar sin volver a serializar nada.
module Webhooks
  class DeliverJob
    include Sidekiq::Job
    sidekiq_options queue: "outbound", retry: false

    TIMEOUT_SECONDS = 5
    MAX_RETRY_WINDOW = 24.hours
    INITIAL_DELAY = 30.seconds

    def perform(delivery_id, attempt = 1)
      delivery = OutboundDelivery.where(id: delivery_id).first
      return unless delivery

      webhook = delivery.outbound_webhook
      return unless webhook&.active?

      deliver(delivery, webhook, delivery.payload.to_json, attempt)
    end

    private

    def deliver(delivery, webhook, body, attempt)
      uri = URI.parse(webhook.url)
      Webhooks::SsrfGuard.check!(uri)

      timestamp = Time.current.to_i.to_s
      response = http_post(uri, webhook, body, timestamp)

      record_result(delivery, webhook, response.status, success: response.status.between?(200, 299))
      retry_or_give_up(delivery, webhook, attempt) unless response.status.between?(200, 299)
    rescue Webhooks::SsrfGuard::BlockedError => e
      record_result(delivery, webhook, nil, success: false, error: e.message)
    rescue StandardError => e
      record_result(delivery, webhook, nil, success: false, error: e.message)
      retry_or_give_up(delivery, webhook, attempt)
    end

    def http_post(uri, webhook, body, timestamp)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      # Faraday con el adaptador net_http por defecto no sigue redirecciones
      # salvo que se añada su middleware explícitamente, que es justo lo que
      # pide la spec (sin seguir redirecciones).
      connection = Faraday.new(url: "#{uri.scheme}://#{uri.host}:#{uri.port}") do |f|
        f.options.open_timeout = TIMEOUT_SECONDS
        f.options.timeout = TIMEOUT_SECONDS
      end

      response = connection.post(uri.request_uri) do |req|
        req.headers["Content-Type"] = "application/json"
        req.headers["X-Hackboard-Event"] = JSON.parse(body)["event"]
        req.headers["X-Hackboard-Delivery"] = JSON.parse(body)["id"]
        req.headers["X-Hackboard-Timestamp"] = timestamp
        req.headers["X-Hackboard-Signature-256"] = Webhooks::Sign.signature(secret: webhook.secret, timestamp: timestamp, body: body)
        req.body = body
      end
      @duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
      response
    end

    def record_result(delivery, webhook, status_code, success:, error: nil)
      delivery.update!(
        status: success ? "succeeded" : "failed",
        attempts: delivery.attempts + 1,
        response_status: status_code,
        duration_ms: @duration_ms || 0
      )

      if success
        webhook.update!(consecutive_failures: 0)
      else
        webhook.inc(consecutive_failures: 1)
        webhook.update!(active: false) if webhook.consecutive_failures >= OutboundWebhook::PAUSE_AFTER_FAILURES
        Rails.logger.info("webhook delivery failed: webhook=#{webhook.id} delivery=#{delivery.id} error=#{error}")
      end
    end

    def retry_or_give_up(delivery, webhook, attempt)
      return unless webhook.active?

      elapsed = Time.current - delivery.created_at
      return if elapsed >= MAX_RETRY_WINDOW

      delay = [INITIAL_DELAY * (2**(attempt - 1)), 1.hour].min
      delivery.update!(next_attempt_at: Time.current + delay, status: "pending")
      self.class.perform_in(delay, delivery.id.to_s, attempt + 1)
    end
  end
end
