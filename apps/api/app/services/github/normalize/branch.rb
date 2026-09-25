# create/delete (ref_type branch) -> branch_created/branch_deleted
# (07-integracion-github.md#normalización-por-evento).
module Github
  module Normalize
    class Branch
      def self.call(team:, repository:, payload:, kind:)
        return unless payload["ref_type"] == "branch"

        branch = payload["ref"]
        dedupe_key = "gh:#{kind}:#{repository.id}:#{branch}:#{Time.current.to_i}"

        ActivityEvent.create!(
          team_id: team.id, source: "github", kind: kind, dedupe_key: dedupe_key,
          occurred_at: Time.current, repository_id: repository.id, branch: branch,
          actor: Github::MapAuthor.call(team: team, login: payload.dig("sender", "login"), email: nil, display_name: nil),
          title: "#{kind == 'branch_created' ? 'Branch created' : 'Branch deleted'}: #{branch}"
        )
      end
    end
  end
end
