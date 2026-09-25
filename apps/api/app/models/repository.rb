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

  has_many :activity_events, dependent: :nullify

  validates :github_repo_id, presence: true
  validates :full_name, presence: true
  validate :only_one_active_repo_per_github_repo_id

  index({ github_repo_id: 1, active: 1 })

  private

  def only_one_active_repo_per_github_repo_id
    return unless active

    conflict = Repository.where(github_repo_id: github_repo_id, active: true).where(:id.ne => id).exists?
    errors.add(:base, "another team already has this repository active") if conflict
  end
end
