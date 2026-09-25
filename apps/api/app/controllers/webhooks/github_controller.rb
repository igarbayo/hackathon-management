# RF-GH-006. It does not inherit from Api::V1::BaseController: there is no
# session or CSRF, only GitHub's HMAC signature.
module Webhooks
  class GithubController < ApplicationController
    def create
      payload_body = request.body.read

      unless Github::WebhookSignature.valid?(payload_body, request.headers["X-Hub-Signature-256"])
        return render_error(:unauthorized, "unauthenticated", "invalid signature")
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
