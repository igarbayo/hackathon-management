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
  validate :has_login_method

  has_many :memberships, dependent: :destroy

  # ADR-0018: con un login de GitHub o un email nuevos, la persona puede
  # reclamar eventos de GitHub sin usuario en todos sus equipos.
  after_update :enqueue_claims, if: -> { (previous_changes.keys & %w[github_login email]).any? }
  has_many :sessions, dependent: :destroy

  index({ email: 1 }, { unique: true })
  index({ github_uid: 1 }, { unique: true, sparse: true })
  index({ google_sub: 1 }, { unique: true, sparse: true })

  # Clave personal de Gemini (06-analisis-ia.md#proveedor, RF-AI-021): cada
  # persona pone la suya para que la IA de sus equipos la use en vez de una
  # clave compartida del servidor. Se guarda cifrada (GeminiApiKeyCipher);
  # el getter descifra bajo demanda, nunca se cachea en memoria.
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

  # RF-TEAM-013: se llama al crear equipo, al unirse y en cada petición de
  # dominio con sesión (TeamScoping), para que "el último equipo abierto"
  # no dependa de un único punto que se pueda olvidar actualizar.
  def remember_last_team!(team_id)
    return if last_team_id == team_id

    set(last_team_id: team_id)
  end

  private

  def enqueue_claims
    memberships.each { |membership| Activity::ClaimForMembershipJob.perform_async(membership.id.to_s) }
  end

  def has_login_method
    return if password_digest.present? || github_uid.present? || google_sub.present?

    errors.add(:base, "hace falta contraseña, GitHub o Google para poder iniciar sesión")
  end
end
