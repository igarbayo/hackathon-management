class Hackathon
  include Mongoid::Document

  embedded_in :team

  field :name, type: String
  field :starts_at, type: Time
  field :ends_at, type: Time
  field :timezone, type: String
  field :url, type: String
  field :challenge_text, type: String

  validates :name, presence: true
  validates :timezone, presence: true
  validate :timezone_is_valid_iana
  validates :challenge_text, length: { maximum: 10_000 }
  validate :ends_after_starts

  private

  def timezone_is_valid_iana
    return if timezone.blank?

    errors.add(:timezone, "must be a valid IANA identifier") unless TZInfo::Timezone.all_identifiers.include?(timezone)
  end

  def ends_after_starts
    return if starts_at.blank? || ends_at.blank?

    errors.add(:ends_at, "must be after starts_at") if ends_at <= starts_at
  end
end
