class Objective
  include Mongoid::Document
  include Mongoid::Timestamps
  include TeamScoped

  PRIORITIES = %w[must should could].freeze

  field :number, type: Integer
  field :title, type: String
  field :description, type: String
  field :priority, type: String
  field :position, type: Integer
  field :archived_at, type: Time
  field :created_by_id, type: BSON::ObjectId

  before_validation :assign_number, on: :create

  validates :title, presence: true, length: { minimum: 1, maximum: 120 }
  validates :description, length: { maximum: 2000 }
  validates :priority, inclusion: { in: PRIORITIES }
  validates :number, presence: true, uniqueness: { scope: :team_id }

  index({ team_id: 1, number: 1 }, { unique: true })

  scope :active, -> { where(archived_at: nil) }

  def key
    "O-#{number}"
  end

  def archived?
    archived_at.present?
  end

  private

  def assign_number
    return if number.present?
    return if team.blank?

    self.number = team.next_objective_number!
  end
end
