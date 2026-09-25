# push -> one commit ActivityEvent per commit
# (07-integracion-github.md#normalización-por-evento).
module Github
  module Normalize
    class Push
      MERGE_COMMIT_PATTERN = /\AMerge pull request #\d+/
      MAX_COMMITS_IN_PAYLOAD = 20

      def self.call(team:, repository:, payload:)
        new(team: team, repository: repository, payload: payload).call
      end

      def initialize(team:, repository:, payload:)
        @team = team
        @repository = repository
        @payload = payload
      end

      def call
        return if tag_push?

        commits.each { |commit| create_event_for(commit) }
      end

      private

      attr_reader :team, :repository, :payload

      def tag_push?
        !payload["ref"].to_s.start_with?("refs/heads/")
      end

      def branch
        payload["ref"].to_s.sub("refs/heads/", "")
      end

      def commits
        raw = payload["forced"] ? [ payload["head_commit"] ].compact : Array(payload["commits"])
        raw = fetch_full_commit_list if raw.size == MAX_COMMITS_IN_PAYLOAD && !payload["forced"]

        raw.reject { |c| merge_commit_on_default_branch?(c) }
      end

      def fetch_full_commit_list
        client = Github::Client.new(repository.installation_id)
        client.compare(repository.full_name, payload["before"], payload["after"])["commits"]
      rescue StandardError
        Array(payload["commits"])
      end

      def merge_commit_on_default_branch?(commit)
        branch == repository.default_branch && commit["message"].to_s.match?(MERGE_COMMIT_PATTERN)
      end

      def create_event_for(commit)
        dedupe_key = "gh:commit:#{commit['id'] || commit['sha']}"
        return if ActivityEvent.where(team_id: team.id, dedupe_key: dedupe_key).exists?

        sha = commit["id"] || commit["sha"]
        message = commit["message"].to_s
        first_line, *rest = message.split("\n", 2)

        actor = Github::MapAuthor.call(
          team: team,
          login: commit.dig("author", "username") || payload.dig("sender", "login"),
          email: commit.dig("author", "email"),
          display_name: commit.dig("author", "name")
        )

        ActivityEvent.create!(
          team_id: team.id, source: "github", kind: "commit", dedupe_key: dedupe_key,
          occurred_at: commit["timestamp"] ? Time.parse(commit["timestamp"]) : Time.current,
          actor: actor, repository_id: repository.id, branch: branch, sha: sha,
          url: commit["url"], title: first_line.to_s.first(200),
          payload: { "message_body" => rest.first.to_s.first(1000) }
        )

        Github::FetchCommitStatsJob.perform_async(team.id.to_s, repository.id.to_s, sha)
      end
    end
  end
end
