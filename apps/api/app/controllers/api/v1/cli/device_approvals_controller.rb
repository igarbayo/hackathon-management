# POST /teams/:team_id/cli/device/approve y /deny (RF-CC-002). Con sesión:
# hereda de BaseController para exigir CSRF (RNF-SEC-003).
module Api
  module V1
    module Cli
      class DeviceApprovalsController < Api::V1::BaseController
        include TeamScoping

        session_only :approve, :deny

        def approve
          ::Cli::ApproveDevice.call(
            team: current_team,
            membership: current_membership,
            user_code: params[:user_code],
            privacy_level: params[:privacy_level]
          )
          head :no_content
        end

        def deny
          ::Cli::DenyDevice.call(team: current_team, user_code: params[:user_code])
          head :no_content
        end
      end
    end
  end
end
