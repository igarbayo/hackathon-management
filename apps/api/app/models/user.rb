class User
  include Mongoid::Document
  include Mongoid::Timestamps
  include ActiveModel::SecurePassword

  field :email, type: String
  field :name, type: String
  field :password_digest, type: String
  field :github_uid, type: Integer
  field :github_login, type: String
  field :google_sub, type: String
  field :avatar_url, type: String
  field :last_team_id, type: BSON::ObjectId
  field :gemini_api_key_encrypted, type: String

  has_secure_password validations: false

  before_validation { email&.downcase!&.strip! }

  validates :email, presence: true, uniqueness: true,
                     format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true, length: { minimum: 1, maximum: 80 }
  validates :github_uid, uniqueness: true, allow_nil: true
  validates :google_sub, uniqueness: true, allow_nil: true
  validates :password, length: { minimum: 10 }, if: -> { password.present? }
  validate :password_fits_bcrypt
  validate :has_login_method

  has_many :memberships, dependent: :destroy

  # ADR-0018: with a new GitHub login or email, the person can claim GitHub
  # events with no user in all their teams.
  after_update :enqueue_claims, if: -> { (previous_changes.keys & %w[github_login email]).any? }
  has_many :sessions, dependent: :destroy

  index({ email: 1 }, { unique: true })
  index({ github_uid: 1 }, { unique: true, sparse: true })
  index({ google_sub: 1 }, { unique: true, sparse: true })

  # Personal Gemini key (06-analisis-ia.md#proveedor, RF-AI-021): each person
  # sets their own so their teams' AI uses it instead of a shared server key. It
  # is stored encrypted (GeminiApiKeyCipher); the getter decrypts it on demand,
  # it is never cached in memory.
  def gemini_api_key
    return nil if gemini_api_key_encrypted.blank?

    GeminiApiKeyCipher.decrypt(gemini_api_key_encrypted)
  end

  def gemini_api_key=(value)
    self.gemini_api_key_encrypted = value.present? ? GeminiApiKeyCipher.encrypt(value) : nil
  end

  def gemini_api_key_configured?
    gemini_api_key_encrypted.present?
  end

  # RF-TEAM-013: it is called when creating a team, when joining and on every
  # domain request with a session (TeamScoping), so "the last opened team" does
  # not depend on a single spot that someone could forget to update.
  def remember_last_team!(team_id)
    return if last_team_id == team_id

    set(last_team_id: team_id)
  end

  private

  def enqueue_claims
    memberships.each { |membership| Activity::ClaimForMembershipJob.perform_async(membership.id.to_s) }
  end

  # bcrypt only uses the first 72 bytes: beyond that, two passwords that start
  # the same would give the same hash. It counts bytes, not characters (an "ñ"
  # takes 2). `has_secure_password validations: false` does not check it by
  # itself.
  def password_fits_bcrypt
    return if password.blank?
    return if password.bytesize <= ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED

    errors.add(:password, "is too long (maximum 72 bytes; about 72 characters without accents)")
  end

  def has_login_method
    return if password_digest.present? || github_uid.present? || google_sub.present?

    errors.add(:base, "a password, GitHub or Google is required to log in")
  end
end
