# installation (deleted/suspend) and installation_repositories (removed): they set
# Repository.active = false (07-integracion-github.md#normalización-por-evento). They
# do not create an ActivityEvent.
module Github
  module Normalize
    class Installation
      def self.deactivate_all(installation_id)
        ::Repository.where(installation_id: installation_id).update_all(active: false)
      end

      def self.deactivate_repos(github_repo_ids)
        ::Repository.where(:github_repo_id.in => github_repo_ids).update_all(active: false)
      end
    end
  end
end
