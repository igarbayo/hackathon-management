# PATCH/DELETE /teams/:team_id/me/claude_code (RF-CC-010, through the session —
# the web app does not have the member token at hand). Each member can only
# change their own link, never someone else's. Same contract as
# Cli::MeController, which is the equivalent Bearer route for the CLI.
module Api
  module V1
    class ClaudeCodeController < Api::V1::BaseController
      include TeamScoping

      session_only :update, :destroy

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
