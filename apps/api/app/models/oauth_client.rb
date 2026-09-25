# It has no team_id: an OAuth client (e.g. claude.ai) works for any team. An
# exception, together with User and Session, to the multi-tenant rule
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
