# PATCH/DELETE /teams/:team_id/me/claude_code (RF-CC-010, vía sesión —
# la web no tiene el token de miembro a mano). Cada miembro solo puede tocar
# su propio enlace, nunca el de otro. Mismo contrato que Cli::MeController,
# que es la vía equivalente con Bearer para el CLI.
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
