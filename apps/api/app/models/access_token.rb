class AccessToken
  include Mongoid::Document
  include Mongoid::Timestamps
  include TeamScoped

  KINDS = %w[pat oauth integration].freeze
  REVOKE_REASONS = %w[manual member_left account_deleted team_deleted refresh_reuse].freeze
  MAX_ACTIVE_PATS_PER_MEMBERSHIP = 10
  MAX_ACTIVE_INTEGRATION_TOKENS_PER_TEAM = 10
  MAX_LIFETIME = 90.days

  field :kind, type: String
  field :membership_id, type: BSON::ObjectId
  field :user_id, type: BSON::ObjectId
  field :created_by_id, type: BSON::ObjectId
  field :oauth_client_id, type: BSON::ObjectId
  field :refresh_token_digest, type: String
  field :refresh_family_id, type: String
  field :resource, type: String
  field :name, type: String
  field :token_digest, type: String
  field :token_prefix, type: String
  field :scopes, type: Array, default: []
  field :expires_at, type: Time
  field :last_used_at, type: Time
  field :revoked_at, type: Time
  field :revoked_by_id, type: BSON::ObjectId
  field :revoke_reason, type: String

  belongs_to :membership, optional: true
  belongs_to :oauth_client, optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :name, presence: true, length: { minimum: 1, maximum: 60 }
  validates :token_digest, presence: true, uniqueness: true
  validates :token_prefix, presence: true
  validates :expires_at, presence: true
  validates :revoke_reason, inclusion: { in: REVOKE_REASONS }, allow_nil: true
  validate :scopes_never_include_ingest
  validate :integration_scopes_restricted, if: -> { kind == "integration" }
  validate :expires_within_max_lifetime, on: :create
  validate :pat_limit_per_membership, on: :create, if: -> { kind == "pat" }
  validate :integration_limit_per_team, on: :create, if: -> { kind == "integration" }

  index({ token_digest: 1 }, { unique: true })
  index({ team_id: 1, membership_id: 1, revoked_at: 1 })
  index({ refresh_token_digest: 1 }, { unique: true, sparse: true })
  index({ oauth_client_id: 1 })

  scope :active, -> { where(revoked_at: nil).and(:expires_at.gt => Time.current) }

  def revoked?
    revoked_at.present?
  end

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  private

  def scopes_never_include_ingest
    errors.add(:scopes, "cannot include the ingest scope") if scopes&.include?("ingest")
  end

  # An integration token acts as the team, not as a person: it cannot report progress, which belongs to
  # someone (12-acceso-programatico.md#tokens-de-integración-de-equipo).
  def integration_scopes_restricted
    errors.add(:scopes, "cannot include progress:write in an integration token") if scopes&.include?("progress:write")
  end

  def expires_within_max_lifetime
    return if expires_at.blank?

    errors.add(:expires_at, "cannot be more than 90 days after creation") if expires_at > MAX_LIFETIME.from_now + 1.minute
  end

  def pat_limit_per_membership
    return if membership_id.blank?

    active_count = self.class.active.where(kind: "pat", membership_id: membership_id).count
    errors.add(:base, "there are already #{MAX_ACTIVE_PATS_PER_MEMBERSHIP} active personal access tokens") if active_count >= MAX_ACTIVE_PATS_PER_MEMBERSHIP
  end

  def integration_limit_per_team
    active_count = self.class.active.where(kind: "integration", team_id: team_id).count
    errors.add(:base, "there are already #{MAX_ACTIVE_INTEGRATION_TOKENS_PER_TEAM} active integration tokens in the team") if active_count >= MAX_ACTIVE_INTEGRATION_TOKENS_PER_TEAM
  end
end
