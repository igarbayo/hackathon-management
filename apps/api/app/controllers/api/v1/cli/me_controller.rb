# PATCH/DELETE /cli/me (RF-CC-010, vía Bearer). El CLI solo tiene el token
# de miembro, nunca la cookie de sesión: es el equivalente de
# Api::V1::ClaudeCodeController para hackboard pause/resume/privacy/uninstall.
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
