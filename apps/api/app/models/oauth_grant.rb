class OAuthGrant
  include Mongoid::Document
  include Mongoid::Timestamps
  include TeamScoped

  DEFAULT_TTL = 60.seconds

  field :code_digest, type: String
  field :oauth_client_id, type: BSON::ObjectId
  field :user_id, type: BSON::ObjectId
  field :membership_id, type: BSON::ObjectId
  field :scopes, type: Array, default: []
  field :redirect_uri, type: String
  field :resource, type: String
  field :code_challenge, type: String
  field :expires_at, type: Time
  field :used_at, type: Time

  belongs_to :oauth_client
  belongs_to :user
  belongs_to :membership

  validates :code_digest, presence: true, uniqueness: true
  validates :redirect_uri, presence: true
  validates :code_challenge, presence: true
  validates :expires_at, presence: true

  index({ code_digest: 1 }, { unique: true })
  index({ expires_at: 1 }, { expire_after_seconds: 0 })

  def used?
    used_at.present?
  end

  def expired?
    expires_at <= Time.current
  end
end
