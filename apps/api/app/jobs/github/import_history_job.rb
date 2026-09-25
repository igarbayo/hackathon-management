# RF-GH-023: al vincular un repo se importa el histórico reciente. Alcance:
# los commits de la rama por defecto desde hackathon.starts_at (máx. 200) y
# los PRs abiertos. RNF-GH-003: también sirve para "Resincronizar".
# RF-GH-025: el resultado queda en repository.last_import.
module Github
  class ImportHistoryJob
    include Sidekiq::Job
    sidekiq_options queue: "github", retry: 3

    MAX_COMMITS = 200

    # Encola la importación y la marca como pendiente, para que la interfaz
    # no muestre el resultado de la anterior mientras tanto.
    def self.enqueue(repository)
      repository.set(last_import: { "status" => "queued" })
      perform_async(repository.id.to_s)
    end

    def perform(repository_id)
      repository = ::Repository.where(id: repository_id).first
      return unless repository

      team = ::Team.where(id: repository.team_id).first
      return unless team

      repository.set(last_import: { "status" => "running" })
      since = team.hackathon&.starts_at

      client = Github::Client.new(repository.installation_id)
      commits = since ? import_commits(client, team, repository, since) : 0
      pull_requests = import_open_pull_requests(client, team, repository)

      repository.set(last_import: {
        "status" => "done", "commits" => commits, "pull_requests" => pull_requests,
        "since" => since&.utc&.iso8601, "reason" => (since ? nil : "no_starts_at"),
        "finished_at" => Time.current.utc.iso8601
      }.compact)
    rescue Github::Client::RateLimited => e
      repository&.set(last_import: { "status" => "queued" })
      self.class.perform_at(e.reset_at, repository_id)
    rescue StandardError
      repository&.set(last_import: { "status" => "failed", "finished_at" => Time.current.utc.iso8601 })
      raise
    end

    private

    # Devuelve cuántos commits hay desde `since` (hasta MAX_COMMITS), estén ya
    # importados o no: es lo que se enseña al usuario.
    def import_commits(client, team, repository, since)
      commits = client.get_commits(repository.full_name, sha: repository.default_branch, since: since).first(MAX_COMMITS)

      commits.each do |commit|
        dedupe_key = "gh:commit:#{commit['sha']}"
        next if ActivityEvent.where(team_id: team.id, dedupe_key: dedupe_key).exists?

        message = commit.dig("commit", "message").to_s
        first_line, *rest = message.split("\n", 2)

        actor = Github::MapAuthor.call(
          team: team,
          login: commit.dig("author", "login"),
          email: commit.dig("commit", "author", "email"),
          display_name: commit.dig("commit", "author", "name")
        )

        ActivityEvent.create!(
          team_id: team.id, source: "github", kind: "commit", dedupe_key: dedupe_key,
          occurred_at: Time.parse(commit.dig("commit", "author", "date")),
          actor: actor, repository_id: repository.id, branch: repository.default_branch, sha: commit["sha"],
          url: commit["html_url"], title: first_line.to_s.first(200),
          payload: { "message_body" => rest.first.to_s.first(1000) }
        )

        Github::FetchCommitStatsJob.perform_async(team.id.to_s, repository.id.to_s, commit["sha"])
      end

      commits.size
    end

    def import_open_pull_requests(client, team, repository)
      pull_requests = client.pull_requests(repository.full_name, state: "open")

      pull_requests.each do |pr|
        dedupe_key = "gh:pr:#{pr['number']}:pr_opened"
        next if ActivityEvent.where(team_id: team.id, dedupe_key: dedupe_key).exists?

        actor = Github::MapAuthor.call(team: team, login: pr.dig("user", "login"), email: nil, display_name: nil)

        event = ActivityEvent.create!(
          team_id: team.id, source: "github", kind: "pr_opened", dedupe_key: dedupe_key,
          occurred_at: Time.parse(pr["created_at"]), actor: actor, repository_id: repository.id,
          branch: pr.dig("head", "ref"), pr_number: pr["number"], url: pr["html_url"], title: pr["title"].to_s.first(200)
        )

        Github::FetchPullRequestFilesJob.perform_async(team.id.to_s, repository.id.to_s, event.id.to_s, pr["number"])
      end

      pull_requests.size
    end
  end
end
