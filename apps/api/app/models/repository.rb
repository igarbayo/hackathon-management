class Repository
  include Mongoid::Document
  include Mongoid::Timestamps
  include TeamScoped

  field :github_repo_id, type: Integer
  field :full_name, type: String
  field :default_branch, type: String
  field :installation_id, type: Integer
  field :active, type: Mongoid::Boolean, default: true
  field :remote_urls, type: Array, default: []
  # RF-GH-025: result of the last history import, so the UI can say how many
  # commits and PRs it brought (or why none).
  field :last_import, type: Hash

  has_many :activity_events, dependent: :nullify

  validates :github_repo_id, presence: true
  validates :full_name, presence: true
  validate :only_one_active_repo_per_github_repo_id

  index({ github_repo_id: 1, active: 1 })

  # RF-GH-025: last_import as the UI should see it. A queued or running import
  # past its `expires_at` (or without one, from before it existed) was lost:
  # it is reported as failed with reason "stalled", so the UI offers Resync.
  def current_import
    return last_import unless %w[queued running].include?(last_import&.dig("status"))

    expires_at = last_import["expires_at"].presence && Time.zone.parse(last_import["expires_at"])
    return last_import if expires_at && expires_at > Time.current

    { "status" => "failed", "reason" => "stalled" }
  end

  private

  def only_one_active_repo_per_github_repo_id
    return unless active

    conflict = Repository.where(github_repo_id: github_repo_id, active: true).where(:id.ne => id).exists?
    errors.add(:base, "another team already has this repository active") if conflict
  end
end
