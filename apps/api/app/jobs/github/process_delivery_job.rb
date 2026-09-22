# RF-GH-006. Resuelve el equipo por repository.id -> Repository activo. Si no
# hay ninguno, marca ignored (07-integracion-github.md#recepción-de-webhooks).
module Github
  class ProcessDeliveryJob
    include Sidekiq::Job
    sidekiq_options queue: "webhooks", retry: 5

    def perform(delivery_id, event, raw_body)
      delivery = WebhookDelivery.where(delivery_id: delivery_id).first
      payload = JSON.parse(raw_body)

      github_repo_id = payload.dig("repository", "id")
      delivery&.update(github_repo_id: github_repo_id)

      case event
      when "installation"
        handle_installation(payload)
      when "installation_repositories"
        handle_installation_repositories(payload)
      when "repository"
        Github::Normalize::RepositoryRenamed.call(payload)
      else
        handle_repository_scoped_event(event, payload, delivery)
        return
      end

      delivery&.update(status: "processed")
    rescue StandardError => e
      delivery&.update(status: "failed", error: e.message.to_s.first(500))
      raise
    end

    private

    def handle_repository_scoped_event(event, payload, delivery)
      github_repo_id = payload.dig("repository", "id")
      repository = ::Repository.where(github_repo_id: github_repo_id, active: true).first

      unless repository
        delivery&.update(status: "ignored")
        return
      end

      delivery&.update(installation_id: repository.installation_id)
      team = ::Team.where(id: repository.team_id).first
      unless team
        delivery&.update(status: "ignored")
        return
      end

      case event
      when "push"
        Github::Normalize::Push.call(team: team, repository: repository, payload: payload)
      when "pull_request"
        Github::Normalize::PullRequest.call(team: team, repository: repository, payload: payload)
      when "create"
        Github::Normalize::Branch.call(team: team, repository: repository, payload: payload, kind: "branch_created")
      when "delete"
        Github::Normalize::Branch.call(team: team, repository: repository, payload: payload, kind: "branch_deleted")
      end

      delivery&.update(status: "processed")
    end

    def handle_installation(payload)
      return unless %w[deleted suspend].include?(payload["action"])

      Github::Normalize::Installation.deactivate_all(payload.dig("installation", "id"))
    end

    def handle_installation_repositories(payload)
      return unless payload["action"] == "removed"

      ids = Array(payload["repositories_removed"]).map { |r| r["id"] }
      Github::Normalize::Installation.deactivate_repos(ids)
    end
  end
end
