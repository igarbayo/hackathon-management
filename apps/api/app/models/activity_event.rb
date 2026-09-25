class ActivityEvent
  include Mongoid::Document
  include Mongoid::Timestamps
  include TeamScoped

  SOURCES = %w[github claude_code mcp system].freeze

  KINDS_BY_SOURCE = {
    "github" => %w[commit pr_opened pr_merged pr_closed pr_reopened branch_created branch_deleted],
    "claude_code" => %w[cc_session_start cc_session_end cc_turn cc_prompt system_test],
    "mcp" => %w[progress_report],
    "system" => %w[feature_status_changed feature_assigned member_joined api_change]
  }.freeze

  MAX_FILES = 50

  # RF-ATR-001…003: kinds sobre los que corre la atribución automática.
  ATTRIBUTABLE_KINDS = %w[commit pr_opened pr_merged pr_closed pr_reopened cc_turn progress_report].freeze

  field :source, type: String
  field :kind, type: String
  field :dedupe_key, type: String
  field :occurred_at, type: Time
  field :received_at, type: Time, default: -> { Time.current }
  field :actor, type: Hash, default: {}
  field :repository_id, type: BSON::ObjectId
  field :branch, type: String
  # Solo commits (RF-GH-026): todas las ramas en las que se ha visto el
  # commit. `branch` es la primera en la que apareció, preferiblemente una
  # que no sea la rama por defecto.
  field :branches, type: Array, default: []
  field :sha, type: String
  field :pr_number, type: Integer
  field :url, type: String
  field :title, type: String
  field :summary, type: String
  field :files, type: Array, default: []
  field :stats, type: Hash, default: {}
  field :payload, type: Hash, default: {}
  field :mentioned_feature_keys, type: Array, default: []
  field :session_ref, type: String
  field :via, type: Hash

  # Capa 3 (05-atribucion.md#capa-3): cuándo se intentó sugerir con IA y
  # salió con confidence < 0.5. No se reintenta hasta que llegue un evento
  # nuevo en el mismo grupo (actor, rama, sesión).
  field :ai_suggestion_attempted_at, type: Time

  embeds_one :attribution, class_name: "EventAttribution"

  belongs_to :repository, optional: true

  validates :source, inclusion: { in: SOURCES }
  validates :dedupe_key, presence: true, uniqueness: { scope: :team_id }
  validates :occurred_at, presence: true
  validates :title, length: { maximum: 200 }
  validates :summary, length: { maximum: 500 }
  validate :kind_matches_source
  validate :files_within_limit

  after_create :enqueue_attribution, if: -> { ATTRIBUTABLE_KINDS.include?(kind) && attribution.blank? }
  # activity.created (12-acceso-programatico.md#webhooks-salientes): nunca
  # para claude_code/mcp, que son opt-in por persona (09-privacidad-seguridad.md#principios).
  after_create :enqueue_activity_webhook, if: -> { %w[github system].include?(source) }

  index({ team_id: 1, dedupe_key: 1 }, { unique: true })
  index({ team_id: 1, occurred_at: -1 })
  index({ team_id: 1, branches: 1, occurred_at: -1 })
  index({ team_id: 1, "attribution.feature_id" => 1, occurred_at: -1 })
  index({ team_id: 1, "actor.user_id" => 1, occurred_at: -1 })
  index({ team_id: 1, "attribution.status" => 1 })
  index({ team_id: 1, "via.token_id" => 1, occurred_at: -1 }, { sparse: true })

  scope :pending_attribution, -> { where("attribution.status" => "suggested") }
  scope :for_feature, ->(feature) { where("attribution.feature_id" => feature.id) }

  # Los eventos anteriores a RF-GH-026 solo tienen `branch`.
  def all_branches
    branches.presence || [ branch ].compact
  end

  private

  def kind_matches_source
    allowed = KINDS_BY_SOURCE[source]
    return if allowed.nil? # ya se marca el error de source por separado

    errors.add(:kind, "no es válido para el source #{source}") unless allowed.include?(kind)
  end

  def files_within_limit
    errors.add(:files, "no puede tener más de #{MAX_FILES} elementos") if files.size > MAX_FILES
  end

  def enqueue_attribution
    Attribution::ConventionJob.perform_async(id.to_s)
  end

  def enqueue_activity_webhook
    team = Team.where(id: team_id).first
    return unless team

    Webhooks::Enqueue.call(team: team, event: "activity.created", data: ActivityEventSerializer.new(self).as_json)
  end
end
