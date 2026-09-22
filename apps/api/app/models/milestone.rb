class Milestone
  include Mongoid::Document
  include Mongoid::Timestamps
  include TeamScoped

  KINDS = %w[checkpoint demo submission custom].freeze

  field :title, type: String
  field :kind, type: String
  field :due_at, type: Time
  field :description, type: String
  field :due_soon_notified_at, type: Time

  validates :title, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :due_at, presence: true

  index({ team_id: 1, due_at: 1 })

  scope :upcoming, -> { where(:due_at.gt => Time.current).order(due_at: :asc) }

  before_update :reset_due_soon_notification, if: :due_at_changed?

  private

  def reset_due_soon_notification
    self.due_soon_notified_at = nil
  end
end
