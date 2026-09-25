# /teams/:team_id/webhooks (RF-API-009). Owners only, session only.
module Api
  module V1
    class WebhooksController < Api::V1::BaseController
      include TeamScoping

      session_only :index, :create, :update, :destroy, :test, :rotate_secret, :deliveries, :redeliver

      def index
        require_owner!
        webhooks = OutboundWebhook.where(team_id: current_team.id)
        render json: { data: webhooks.map { |w| OutboundWebhookSerializer.new(w).as_json } }
      end

      def create
        require_owner!
        secret = SecureRandom.hex(32)
        webhook = OutboundWebhook.new(url: params[:url], events: Array(params[:events]))
        webhook.team = current_team
        webhook.created_by_id = current_user.id
        webhook.secret = secret
        webhook.save!

        Webhooks::Enqueue.call(team: current_team, event: "ping", data: { message: "Webhook created" })

        render json: OutboundWebhookSerializer.new(webhook).as_json.merge(secret: secret), status: :created
      end

      def update
        require_owner!
        webhook = find_webhook
        webhook.update!(params.permit(:url, :active, events: []).to_h)
        render json: OutboundWebhookSerializer.new(webhook).as_json
      end

      def destroy
        require_owner!
        find_webhook.destroy!
        head :no_content
      end

      def test
        require_owner!
        webhook = find_webhook
        Webhooks::Enqueue.call(team: current_team, event: "ping", data: { message: "Manual test" })
        head :accepted
      end

      def rotate_secret
        require_owner!
        webhook = find_webhook
        secret = SecureRandom.hex(32)
        webhook.secret = secret
        webhook.save!
        render json: OutboundWebhookSerializer.new(webhook).as_json.merge(secret: secret)
      end

      def deliveries
        require_owner!
        webhook = find_webhook
        deliveries = OutboundDelivery.where(team_id: current_team.id, outbound_webhook_id: webhook.id).order(created_at: :desc).limit(50)
        render json: { data: deliveries.map { |d| OutboundDeliverySerializer.new(d).as_json } }
      end

      def redeliver
        require_owner!
        webhook = find_webhook
        delivery = OutboundDelivery.where(team_id: current_team.id, outbound_webhook_id: webhook.id, id: params[:delivery_id]).first
        raise ApiError::NotFound.new(message: "delivery not found") unless delivery

        Webhooks::DeliverJob.perform_async(delivery.id.to_s)
        head :accepted
      end

      private

      def find_webhook
        OutboundWebhook.where(team_id: current_team.id, id: params[:id] || params[:webhook_id]).first.tap do |webhook|
          raise ApiError::NotFound.new(message: "webhook not found") unless webhook
        end
      end
    end
  end
end
