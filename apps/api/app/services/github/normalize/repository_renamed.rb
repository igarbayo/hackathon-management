# repository (renamed): actualiza full_name y remote_urls
# (07-integracion-github.md#normalización-por-evento). No genera ActivityEvent.
module Github
  module Normalize
    class RepositoryRenamed
      def self.call(payload)
        return unless payload["action"] == "renamed"

        github_repo_id = payload.dig("repository", "id")
        full_name = payload.dig("repository", "full_name")
        return if github_repo_id.blank? || full_name.blank?

        ::Repository.where(github_repo_id: github_repo_id).each do |repository|
          repository.update!(full_name: full_name, remote_urls: [ normalized_url(full_name) ])
        end
      end

      def self.normalized_url(full_name)
        "github.com/#{full_name}"
      end
    end
  end
end
