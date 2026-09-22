class Feature
  include Mongoid::Document
  include Mongoid::Timestamps
  include TeamScoped

  STATUSES = %w[idea in_progress done discarded].freeze

  field :number, type: Integer
  field :title, type: String
  field :description, type: String
  field :status, type: String, default: "idea"
  field :position, type: Float, default: 0.0
  field :objective_ids, type: Array, default: []
  field :assignee_ids, type: Array, default: []
  field :deadline, type: Time
  field :branch_names, type: Array, default: []
  field :discarded_reason, type: String
  field :status_changed_at, type: Time
  field :created_by_id, type: BSON::ObjectId

  embeds_many :arguments

  before_validation :assign_number, on: :create
  before_save :track_status_change, if: -> { status_changed? }

  validates :title, presence: true, length: { minimum: 1, maximum: 120 }
  validates :description, length: { maximum: 5000 }
  validates :status, inclusion: { in: STATUSES }
  validates :number, presence: true, uniqueness: { scope: :team_id }

  index({ team_id: 1, number: 1 }, { unique: true })
  index({ team_id: 1, status: 1, position: 1 })
  index({ team_id: 1, branch_names: 1 })

  def key
    "F-#{number}"
  end

  def score
    arguments.sum { |argument| argument.kind == "pro" ? argument.votes : -argument.votes }
  end

  private

  def assign_number
    return if number.present?
    return if team.blank?

    self.number = team.next_feature_number!
  end

  def track_status_change
    self.status_changed_at = Time.current
  end
end
