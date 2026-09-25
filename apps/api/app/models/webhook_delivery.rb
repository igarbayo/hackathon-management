# Careful: not to be confused with OutboundDelivery. This model records INCOMING
# deliveries from GitHub, for idempotency and debugging (02-modelo-datos.md).
class WebhookDelivery
  include Mongoid::Document
  include Mongoid::Timestamps

  STATUSES = %w[received processed ignored failed].freeze
  RETENTION = 14.days

  field :delivery_id, type: String
  field :event, type: String
  field :installation_id, type: Integer
  field :github_repo_id, type: Integer
  field :status, type: String, default: "received"
  field :error, type: String

  validates :delivery_id, presence: true, uniqueness: true
  validates :event, presence: true
  validates :status, inclusion: { in: STATUSES }

  index({ delivery_id: 1 }, { unique: true })
  index({ created_at: 1 }, { expire_after_seconds: RETENTION.to_i })
end
