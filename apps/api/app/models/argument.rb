class Argument
  include Mongoid::Document
  include Mongoid::Timestamps::Created

  KINDS = %w[pro con].freeze

  embedded_in :feature

  field :kind, type: String
  field :text, type: String
  field :author_id, type: BSON::ObjectId
  field :voter_ids, type: Array, default: []

  validates :kind, inclusion: { in: KINDS }
  validates :text, presence: true, length: { minimum: 1, maximum: 280 }

  def votes
    voter_ids.size
  end
end
