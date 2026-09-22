class Team
  include Mongoid::Document
  include Mongoid::Timestamps

  CODE_ALPHABET = "23456789ABCDEFGHJKMNPQRSTVWXYZ".chars.freeze
  CODE_LENGTH = 8
  PLANS = %w[free pro].freeze

  field :name, type: String
  field :code, type: String
  field :feature_seq, type: Integer, default: 0
  field :objective_seq, type: Integer, default: 0
  field :plan, type: String, default: "free"
  field :settings, type: Hash, default: -> { { "ai_enabled" => true, "ai_attribution_enabled" => true, "claude_code_enabled" => true } }
  field :github_installation_ids, type: Array, default: []
  field :deleted_at, type: Time

  embeds_one :hackathon

  has_many :memberships, dependent: :destroy
  has_many :access_tokens, dependent: :destroy
  has_many :repositories, dependent: :destroy
  has_many :objectives, dependent: :destroy
  has_many :features, dependent: :destroy
  has_many :milestones, dependent: :destroy
  has_many :activity_events, dependent: :destroy
  has_many :ai_analyses, dependent: :destroy
  has_many :outbound_webhooks, dependent: :destroy

  accepts_nested_attributes_for :hackathon

  validates :name, presence: true, length: { minimum: 1, maximum: 60 }
  validates :code, presence: true, uniqueness: true
  validates :plan, inclusion: { in: PLANS }

  before_validation :assign_code, on: :create

  index({ code: 1 }, { unique: true })

  scope :active, -> { where(deleted_at: nil) }

  def formatted_code
    return code if code.blank?

    "#{code[0, 4]}-#{code[4, 4]}"
  end

  def next_feature_number!
    result = self.class.collection.find_one_and_update(
      { _id: id },
      { "$inc" => { feature_seq: 1 } },
      return_document: :after
    )
    result["feature_seq"]
  end

  def next_objective_number!
    result = self.class.collection.find_one_and_update(
      { _id: id },
      { "$inc" => { objective_seq: 1 } },
      return_document: :after
    )
    result["objective_seq"]
  end

  private

  def assign_code
    return if code.present?

    loop do
      candidate = Array.new(CODE_LENGTH) { CODE_ALPHABET.sample }.join
      next if self.class.where(code: candidate).exists?

      self.code = candidate
      break
    end
  end
end
