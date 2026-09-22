class OutboundDelivery
  include Mongoid::Document
  include Mongoid::Timestamps
  include TeamScoped

  STATUSES = %w[pending succeeded failed].freeze
  RETENTION = 14.days

  field :outbound_webhook_id, type: BSON::ObjectId
  field :event, type: String
  field :delivery_id, type: String
  field :status, type: String, default: "pending"
  field :attempts, type: Integer, default: 0
  field :response_status, type: Integer
  field :duration_ms, type: Integer
  field :next_attempt_at, type: Time

  belongs_to :outbound_webhook

  validates :event, presence: true
  validates :delivery_id, presence: true
  validates :status, inclusion: { in: STATUSES }

  index({ team_id: 1, outbound_webhook_id: 1, created_at: -1 })
  index({ created_at: 1 }, { expire_after_seconds: RETENTION.to_i })
end
