# RF-GH-006. No hereda de Api::V1::BaseController: no hay sesión ni CSRF,
# solo la firma HMAC de GitHub.
module Webhooks
  class GithubController < ApplicationController
    def create
      payload_body = request.body.read

      unless Github::WebhookSignature.valid?(payload_body, request.headers["X-Hub-Signature-256"])
        return render_error(:unauthorized, "unauthenticated", "firma inválida")
      end

      delivery_id = request.headers["X-GitHub-Delivery"]
      event = request.headers["X-GitHub-Event"]

      if WebhookDelivery.where(delivery_id: delivery_id).exists?
        return head :ok
      end

      WebhookDelivery.create!(delivery_id: delivery_id, event: event, status: "received")
      Github::ProcessDeliveryJob.perform_async(delivery_id, event, payload_body)

      head :accepted
    end
  end
end
