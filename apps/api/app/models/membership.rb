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

  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :team_id }

  validate :team_keeps_an_owner, on: :update, if: -> { role_changed? }
  before_destroy :ensure_not_last_owner
  after_destroy :revoke_access

  index({ team_id: 1, user_id: 1 }, { unique: true })
  index({ "claude_code.token_digest" => 1 }, { unique: true, sparse: true })

  scope :owners, -> { where(role: "owner") }

  def owner?
    role == "owner"
  end

  private

  def default_display_name
    self.display_name ||= user&.name
  end

  def team_keeps_an_owner
    return unless role_was == "owner" && role != "owner"
    return if other_owners.exists?

    errors.add(:role, "no se puede quitar: es el último owner del equipo")
  end

  def ensure_not_last_owner
    return unless owner?
    return if other_owners.exists?

    errors.add(:base, "no se puede eliminar al último owner del equipo")
    throw :abort
  end

  # RF-TEAM-008: al salir o ser expulsado se revocan sus tokens de este equipo
  # (el de Claude Code va embebido y desaparece con la membresía). Los ya
  # revocados, p. ej. por Accounts::Destroy, conservan su motivo.
  def revoke_access
    AccessToken.where(team_id: team_id, membership_id: id, revoked_at: nil)
               .update_all(revoked_at: Time.current, revoke_reason: "member_left")
    OAuthGrant.where(team_id: team_id, membership_id: id).delete_all
  end

  def other_owners
    Membership.where(team_id: team_id, role: "owner").where(:id.ne => id)
  end
end
