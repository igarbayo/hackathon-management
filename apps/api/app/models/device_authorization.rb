# Device flow del CLI (RF-CC-001, RF-CC-002). Sin team_id/membership_id
# hasta que se aprueba: como User/Session/OAuthClient, es una excepción
# puntual a la regla multi-tenant mientras está pending.
class DeviceAuthorization
  include Mongoid::Document
  include Mongoid::Timestamps

  STATUSES = %w[pending approved denied].freeze
  CODE_ALPHABET = Team::CODE_ALPHABET
  CODE_LENGTH = 8
  TTL = 15.minutes

  field :device_code_digest, type: String
  field :user_code, type: String
  field :team_id, type: BSON::ObjectId
  field :membership_id, type: BSON::ObjectId
  field :status, type: String, default: "pending"
  field :privacy_level, type: String
  field :consumed_at, type: Time
  field :expires_at, type: Time

  belongs_to :team, optional: true
  belongs_to :membership, optional: true

  validates :device_code_digest, presence: true, uniqueness: true
  validates :user_code, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :expires_at, presence: true

  before_validation :assign_user_code, on: :create
  before_validation :assign_expiry, on: :create

  index({ device_code_digest: 1 }, { unique: true })
  index({ user_code: 1 })
  index({ expires_at: 1 }, { expire_after_seconds: 0 })

  def self.find_by_user_code(input)
    where(user_code: input.to_s.strip.upcase.delete("-")).first
  end

  def formatted_user_code
    "#{user_code[0, 4]}-#{user_code[4, 4]}"
  end

  def expired?
    expires_at <= Time.current
  end

  def consumed?
    consumed_at.present?
  end

  private

  def assign_user_code
    return if user_code.present?

    loop do
      candidate = Array.new(CODE_LENGTH) { CODE_ALPHABET.sample }.join
      next if self.class.where(user_code: candidate).exists?

      self.user_code = candidate
      break
    end
  end

  def assign_expiry
    self.expires_at ||= TTL.from_now
  end
end
