class RepositorySerializer
  def initialize(repository)
    @repository = repository
  end

  def as_json
    {
      id: repository.id.to_s,
      github_repo_id: repository.github_repo_id,
      full_name: repository.full_name,
      default_branch: repository.default_branch,
      active: repository.active,
      last_import: repository.last_import
    }
  end

  private

  attr_reader :repository
end
