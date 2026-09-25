class Membership
  include Mongoid::Document
  include Mongoid::Timestamps
  include TeamScoped

  ROLES = %w[owner member].freeze

  field :user_id, type: BSON::ObjectId
  field :role, type: String, default: "member"
  field :display_name, type: String
  field :git_identities, type: Array, default: []

  belongs_to :user
  embeds_one :claude_code, class_name: "ClaudeCodeLink"

  accepts_nested_attributes_for :claude_code

  before_validation :default_display_name, on: :create
  before_validation :normalize_git_identities

  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :team_id }

  validate :team_keeps_an_owner, on: :update, if: -> { role_changed? }
  validate :git_identities_not_taken, if: -> { git_identities_changed? }
  before_destroy :ensure_not_last_owner
  after_destroy :revoke_access

  # ADR-0018: when joining the team or adding identities, the member gets the
  # GitHub events with no user that match them.
  after_create :enqueue_claim
  after_update :enqueue_claim, if: -> { previous_changes.key?("git_identities") }

  index({ team_id: 1, user_id: 1 }, { unique: true })
  index({ "claude_code.token_digest" => 1 }, { unique: true, sparse: true })

  scope :owners, -> { where(role: "owner") }

  def owner?
    role == "owner"
  end

  private

  def enqueue_claim
    Activity::ClaimForMembershipJob.perform_async(id.to_s)
  end

  def normalize_git_identities
    self.git_identities = Array(git_identities).filter_map { |i| Activity::AuthorIdentity.normalize(i) }.uniq
  end

  # An identity cannot belong to two members of the same team.
  def git_identities_not_taken
    return if git_identities.empty?

    taken = Membership.where(team_id: team_id, :id.ne => id, :git_identities.in => git_identities).pluck(:git_identities).flatten & git_identities
    errors.add(:git_identities, "already belong to another team member: #{taken.join(', ')}") if taken.any?
  end

  def default_display_name
    self.display_name ||= user&.name
  end

  def team_keeps_an_owner
    return unless role_was == "owner" && role != "owner"
    return if other_owners.exists?

    errors.add(:role, "cannot be removed: it is the last owner of the team")
  end

  def ensure_not_last_owner
    return unless owner?
    return if other_owners.exists?

    errors.add(:base, "the last owner of the team cannot be removed")
    throw :abort
  end

  # RF-TEAM-008: when leaving or being removed, their tokens for this team are
  # revoked (the Claude Code one is embedded and goes away with the membership).
  # Tokens already revoked, e.g. by Accounts::Destroy, keep their reason.
  def revoke_access
    AccessToken.where(team_id: team_id, membership_id: id, revoked_at: nil)
               .update_all(revoked_at: Time.current, revoke_reason: "member_left")
    OAuthGrant.where(team_id: team_id, membership_id: id).delete_all
  end

  def other_owners
    Membership.where(team_id: team_id, role: "owner").where(:id.ne => id)
  end
end
