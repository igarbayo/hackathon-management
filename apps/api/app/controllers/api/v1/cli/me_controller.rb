# PATCH/DELETE /cli/me (RF-CC-010, through Bearer). The CLI only has the member
# token, never the session cookie: it is the equivalent of
# Api::V1::ClaudeCodeController for hackboard pause/resume/privacy/uninstall.
module Api
  module V1
    module Cli
      class MeController < ApplicationController
        include TokenAuthentication
        before_action :authenticate_member_token!

        def update
          ::Cli::UpdateLink.call(
            membership: current_membership,
            privacy_level: params[:privacy_level],
            paused: params.key?(:paused) ? ActiveModel::Type::Boolean.new.cast(params[:paused]) : nil
          )
          render json: MemberSerializer.new(current_membership).as_json
        end

        def destroy
          ::Cli::RevokeLink.call(membership: current_membership, purge: ActiveModel::Type::Boolean.new.cast(params[:purge]))
          head :no_content
        end
      end
    end
  end
end
