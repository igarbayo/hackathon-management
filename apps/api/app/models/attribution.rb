class Attribution
  include Mongoid::Document

  METHODS = %w[convention branch ai manual].freeze
  STATUSES = %w[confirmed suggested rejected].freeze

  embedded_in :activity_event

  field :feature_id, type: BSON::ObjectId
  field :method, type: String
  field :status, type: String
  field :confidence, type: Float
  field :reason, type: String
  field :decided_by_id, type: BSON::ObjectId
  field :decided_at, type: Time
  field :rejected_feature_ids, type: Array, default: []

  validates :method, inclusion: { in: METHODS }
  validates :status, inclusion: { in: STATUSES }
  validates :reason, length: { maximum: 280 }
  validates :confidence, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }, allow_nil: true
  validates :feature_id, presence: true, unless: -> { status == "rejected" }
end
