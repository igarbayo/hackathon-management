module Api
  module V1
    class GithubController < Api::V1::BaseController
      include TeamScoping

      def install_url
        state = Github::InstallState.generate(team: current_team, user: current_user)
        render json: { url: "https://github.com/apps/#{ENV.fetch('GITHUB_APP_SLUG', '')}/installations/new?state=#{state}" }
      end

      def available_repos
        render json: { data: Github::AvailableRepos.call(current_team) }
      end
    end
  end
end
