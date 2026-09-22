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

  has_secure_password validations: false

  before_validation { email&.downcase!&.strip! }

  validates :email, presence: true, uniqueness: true,
                     format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true, length: { minimum: 1, maximum: 80 }
  validates :github_uid, uniqueness: true, allow_nil: true
  validates :google_sub, uniqueness: true, allow_nil: true
  validate :has_login_method

  has_many :memberships, dependent: :destroy
  has_many :sessions, dependent: :destroy

  index({ email: 1 }, { unique: true })
  index({ github_uid: 1 }, { unique: true, sparse: true })
  index({ google_sub: 1 }, { unique: true, sparse: true })

  private

  def has_login_method
    return if password_digest.present? || github_uid.present? || google_sub.present?

    errors.add(:base, "hace falta contraseña, GitHub o Google para poder iniciar sesión")
  end
end
