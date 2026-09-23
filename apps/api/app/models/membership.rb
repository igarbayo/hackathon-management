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

  # ADR-0018: al entrar en el equipo o añadir identidades, se le asignan los
  # eventos de GitHub sin usuario que coinciden con ellas.
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

  # Una identidad no puede ser de dos miembros del mismo equipo.
  def git_identities_not_taken
    return if git_identities.empty?

    taken = Membership.where(team_id: team_id, :id.ne => id, :git_identities.in => git_identities).pluck(:git_identities).flatten & git_identities
    errors.add(:git_identities, "ya son de otro miembro del equipo: #{taken.join(', ')}") if taken.any?
  end

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

  def other_owners
    Membership.where(team_id: team_id, role: "owner").where(:id.ne => id)
  end
end
