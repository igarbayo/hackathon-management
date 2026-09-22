class AiAnalysis
  include Mongoid::Document
  include Mongoid::Timestamps
  include TeamScoped

  TRIGGERS = %w[scheduled manual].freeze
  STATUSES = %w[queued running succeeded failed skipped].freeze

  field :trigger, type: String
  field :requested_by_id, type: BSON::ObjectId
  field :status, type: String, default: "queued"
  field :skip_reason, type: String
  field :provider, type: String
  field :model, type: String
  field :prompt_version, type: String
  field :input_hash, type: String
  field :context_stats, type: Hash, default: {}
  field :result, type: Hash
  field :deterministic_alerts, type: Array, default: []
  field :usage, type: Hash, default: {}
  field :error, type: String
  field :started_at, type: Time
  field :finished_at, type: Time

  validates :trigger, inclusion: { in: TRIGGERS }
  validates :status, inclusion: { in: STATUSES }

  index({ team_id: 1, created_at: -1 })

  def finished?
    %w[succeeded failed skipped].include?(status)
  end
end
