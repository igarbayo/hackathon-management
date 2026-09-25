# RF-GH-020 step 4: GitHub redirects here after installing the App. It does not
# depend on the web session: the signed state already carries team_id and
# user_id.
module Api
  module V1
    class GithubSetupController < Api::V1::BaseController
      def show
        claims = Github::InstallState.verify(params[:state])
        team = Team.active.where(id: claims["team_id"]).first
        raise ApiError::NotFound.new(message: "team not found") unless team

        membership = Membership.where(team_id: team.id, user_id: claims["user_id"]).first
        raise ApiError::Forbidden.new(message: "you are not a member of this team") unless membership

        installation_id = params[:installation_id].to_i
        team.add_to_set(github_installation_ids: installation_id)

        link_pasted_repo(team, membership, installation_id, claims["pasted_full_name"])

        redirect_to return_url(team, claims["return_to"]), allow_other_host: true
      end

      private

      def return_url(team, return_to)
        app_url = ENV.fetch("APP_URL", "")
        return "#{app_url}/onboarding?team=#{team.id}&step=repo" if return_to == "onboarding"

        "#{app_url}/t/#{team.id}/settings"
      end

      def link_pasted_repo(team, membership, installation_id, full_name)
        return if full_name.blank?

        result = Github::LinkRepository.call(team: team, user: User.where(id: membership.user_id).first, full_name: full_name)
        Github::ImportHistoryJob.enqueue(result.repository) if result.linked
      end
    end
  end
end
