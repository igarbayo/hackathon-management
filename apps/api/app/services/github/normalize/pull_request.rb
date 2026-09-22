# pull_request -> pr_opened/pr_merged/pr_closed/pr_reopened
# (07-integracion-github.md#normalización-por-evento).
module Github
  module Normalize
    class PullRequest
      def self.call(team:, repository:, payload:)
        new(team: team, repository: repository, payload: payload).call
      end

      def initialize(team:, repository:, payload:)
        @team = team
        @repository = repository
        @payload = payload
      end

      def call
        return unless kind

        return if ActivityEvent.where(team_id: team.id, dedupe_key: dedupe_key).exists?

        pr = payload["pull_request"]
        actor = Github::MapAuthor.call(team: team, login: pr.dig("user", "login"), email: nil, display_name: nil)

        event = ActivityEvent.create!(
          team_id: team.id, source: "github", kind: kind, dedupe_key: dedupe_key,
          occurred_at: Time.parse(pr["updated_at"] || pr["created_at"]),
          actor: actor, repository_id: repository.id, branch: pr.dig("head", "ref"),
          pr_number: pr["number"], url: pr["html_url"], title: pr["title"].to_s.first(200)
        )

        Github::FetchPullRequestFilesJob.perform_async(team.id.to_s, repository.id.to_s, event.id.to_s, pr["number"])
      end

      private

      attr_reader :team, :repository, :payload

      def kind
        case payload["action"]
        when "opened" then "pr_opened"
        when "reopened" then "pr_reopened"
        when "closed" then payload.dig("pull_request", "merged") ? "pr_merged" : "pr_closed"
        end
      end

      def dedupe_key
        "gh:pr:#{payload.dig('pull_request', 'number')}:#{kind}"
      end
    end
  end
end
