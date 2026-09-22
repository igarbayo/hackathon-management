module Api
  module V1
    class TeamMembersController < Api::V1::BaseController
      include TeamScoping

      session_only :update, :destroy
      requires_scope "read", only: :index

      def index
        memberships = Membership.where(team_id: current_team.id)
        render json: { data: memberships.map { |m| MemberSerializer.new(m).as_json } }
      end

      def update
        target = Membership.where(team_id: current_team.id, id: params[:id]).first
        raise ApiError::NotFound.new(message: "miembro no encontrado") unless target

        is_self = target.id == current_membership.id

        if params[:role].present?
          require_owner!
          target.role = params[:role]
        end

        if is_self || current_membership.owner?
          target.display_name = params[:display_name] if params[:display_name].present?
          target.git_identities = params[:git_identities] if params.key?(:git_identities)
        end

        target.save!
        render json: MemberSerializer.new(target).as_json
      end

      def destroy
        target = Membership.where(team_id: current_team.id, id: params[:id]).first
        raise ApiError::NotFound.new(message: "miembro no encontrado") unless target

        is_self = target.id == current_membership.id
        raise ApiError::Forbidden.new unless is_self || current_membership.owner?

        unless target.destroy
          raise ApiError::Conflict.new(message: target.errors.full_messages.first || "no se puede eliminar")
        end

        head :no_content
      end
    end
  end
end
