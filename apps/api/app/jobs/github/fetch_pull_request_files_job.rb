# Ficheros de un PR, aparte del evento (máx. 50) (07-integracion-github.md).
module Github
  class FetchPullRequestFilesJob
    include Sidekiq::Job
    sidekiq_options queue: "github", retry: 5

    MAX_FILES = 50

    def perform(team_id, repository_id, event_id, pr_number)
      repository = ::Repository.where(id: repository_id).first
      return unless repository

      event = ActivityEvent.where(id: event_id, team_id: team_id).first
      return unless event

      client = Github::Client.new(repository.installation_id)
      files = client.pull_request_files(repository.full_name, pr_number).first(MAX_FILES).map do |f|
        { "path" => f["filename"], "additions" => f["additions"], "deletions" => f["deletions"] }
      end

      event.update!(files: files, stats: {
        "files_changed" => files.size,
        "additions" => files.sum { |f| f["additions"].to_i },
        "deletions" => files.sum { |f| f["deletions"].to_i }
      })
    rescue Github::Client::RateLimited => e
      self.class.perform_at(e.reset_at, team_id, repository_id, event_id, pr_number)
    rescue Github::Client::NotFound
      nil
    end
  end
end
