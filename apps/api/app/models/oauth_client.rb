# No lleva team_id: un cliente OAuth (p. ej. claude.ai) sirve para cualquier
# equipo. Excepción, junto con User y Session, a la regla multi-tenant
# (02-modelo-datos.md#oauthclient).
class OAuthClient
  include Mongoid::Document
  include Mongoid::Timestamps

  REGISTRATIONS = %w[dynamic metadata_document first_party].freeze

  field :client_id, type: String
  field :registration, type: String
  field :name, type: String
  field :redirect_uris, type: Array, default: []
  field :client_uri, type: String
  field :logo_uri, type: String
  field :last_used_at, type: Time

  has_many :access_tokens, dependent: :destroy
  has_many :oauth_grants, dependent: :destroy

  validates :client_id, presence: true, uniqueness: true
  validates :registration, inclusion: { in: REGISTRATIONS }
  validates :name, presence: true, length: { maximum: 60 }
  validates :redirect_uris, presence: true

  index({ client_id: 1 }, { unique: true })

  def first_party?
    registration == "first_party"
  end
end
