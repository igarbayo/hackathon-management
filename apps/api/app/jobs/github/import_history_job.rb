# RF-GH-023: linking a repo imports its recent history. Scope: commits on the
# default branch since hackathon.starts_at (max. 200) and open PRs. RNF-GH-003:
# it is also used for "Resync".
module Github
  class ImportHistoryJob
    include Sidekiq::Job
    sidekiq_options queue: "github", retry: 3

    MAX_COMMITS = 200

    def perform(repository_id)
      repository = ::Repository.where(id: repository_id).first
      return unless repository

      team = ::Team.where(id: repository.team_id).first
      return unless team

      client = Github::Client.new(repository.installation_id)
      import_commits(client, team, repository)
      import_open_pull_requests(client, team, repository)
    rescue Github::Client::RateLimited => e
      self.class.perform_at(e.reset_at, repository_id)
    end

    private

    def import_commits(client, team, repository)
      since = team.hackathon&.starts_at
      return unless since

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
    end

    def import_open_pull_requests(client, team, repository)
      client.pull_requests(repository.full_name, state: "open").each do |pr|
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
    end
  end
end
