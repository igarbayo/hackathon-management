class OutboundWebhook
  include Mongoid::Document
  include Mongoid::Timestamps
  include TeamScoped

  MAX_PER_TEAM = 5
  PAUSE_AFTER_FAILURES = 50

  field :url, type: String
  field :events, type: Array, default: []
  field :secret_ciphertext, type: String
  field :active, type: Mongoid::Boolean, default: true
  field :consecutive_failures, type: Integer, default: 0
  field :created_by_id, type: BSON::ObjectId

  has_many :outbound_deliveries, dependent: :destroy

  attr_writer :secret

  validates :url, presence: true, format: { with: %r{\Ahttps://}, message: "must be HTTPS" }
  validates :events, presence: true
  validate :secret_present, on: :create
  validate :team_does_not_exceed_max, on: :create

  before_validation :encrypt_secret, if: -> { @secret.present? }
  before_save :pause_after_too_many_failures

  def secret
    return nil if secret_ciphertext.blank?

    WebhookSecretCipher.decrypt(secret_ciphertext)
  end

  private

  def encrypt_secret
    self.secret_ciphertext = WebhookSecretCipher.encrypt(@secret)
  end

  def secret_present
    errors.add(:base, "a signing secret is required") if secret_ciphertext.blank?
  end

  def team_does_not_exceed_max
    return if team_id.blank?

    errors.add(:base, "there are already #{MAX_PER_TEAM} webhooks set up in this team") if OutboundWebhook.where(team_id: team_id).count >= MAX_PER_TEAM
  end

  def pause_after_too_many_failures
    self.active = false if consecutive_failures.to_i >= PAUSE_AFTER_FAILURES
  end
end
