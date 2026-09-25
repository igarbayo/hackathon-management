# 07-integracion-github.md#normalización-por-evento: fetches the commit's files
# and stats separately (max. 50 files). It never stores the patch.
module Github
  class FetchCommitStatsJob
    include Sidekiq::Job
    sidekiq_options queue: "github", retry: 5

    MAX_FILES = 50

    def perform(team_id, repository_id, sha)
      repository = ::Repository.where(id: repository_id).first
      return unless repository

      event = ActivityEvent.where(team_id: team_id, dedupe_key: "gh:commit:#{sha}").first
      return unless event

      client = Github::Client.new(repository.installation_id)
      commit = client.commit(repository.full_name, sha)

      files = Array(commit["files"]).first(MAX_FILES).map do |f|
        { "path" => f["filename"], "additions" => f["additions"], "deletions" => f["deletions"] }
      end

      event.update!(
        files: files,
        stats: {
          "files_changed" => commit.dig("stats", "total") ? Array(commit["files"]).size : files.size,
          "additions" => commit.dig("stats", "additions"),
          "deletions" => commit.dig("stats", "deletions")
        }
      )
    rescue Github::Client::RateLimited => e
      self.class.perform_at(e.reset_at, team_id, repository_id, sha)
    rescue Github::Client::NotFound
      nil
    end
  end
end
