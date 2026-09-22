class Milestone
  include Mongoid::Document
  include Mongoid::Timestamps
  include TeamScoped

  KINDS = %w[checkpoint demo submission custom].freeze

  field :title, type: String
  field :kind, type: String
  field :due_at, type: Time
  field :description, type: String

  validates :title, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :due_at, presence: true

  index({ team_id: 1, due_at: 1 })

  scope :upcoming, -> { where(:due_at.gt => Time.current).order(due_at: :asc) }
end
