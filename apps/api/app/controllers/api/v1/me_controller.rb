module Api
  module V1
    class MeController < Api::V1::BaseController
      before_action :authenticate_user!

      def show
        render json: MeSerializer.new(current_user).as_json
      end

      def update
        attrs = params.permit(:name, :password).to_h.compact_blank
        current_user.update!(attrs)

        render json: MeSerializer.new(current_user).as_json
      end

      def destroy_identity
        provider = params[:provider]
        raise ApiError::BadRequest.new(message: "provider tiene que ser github o google") unless %w[github google].include?(provider)

        field = provider == "github" ? :github_uid : :google_sub
        other_field = provider == "github" ? :google_sub : :github_uid

        if current_user.password_digest.blank? && current_user.public_send(other_field).blank?
          raise ApiError::Conflict.new(message: "es la única forma de iniciar sesión, no se puede desvincular")
        end

        current_user.update!(field => nil)
        render json: MeSerializer.new(current_user).as_json
      end

      def destroy
        memberships = Membership.where(user_id: current_user.id).to_a

        memberships.each do |membership|
          other_members = Membership.where(team_id: membership.team_id).where(:id.ne => membership.id)
          other_owners = other_members.where(role: "owner")

          next unless membership.owner? && other_owners.empty?

          if other_members.exists?
            raise ApiError::Conflict.new(
              message: "eres el único owner de \"#{membership.team.name}\" y tiene más miembros: " \
                       "transfiere la propiedad antes de borrar la cuenta"
            )
          end
        end

        memberships.each do |membership|
          team = membership.team
          orphaning_team = membership.owner? && Membership.where(team_id: team.id).where(:id.ne => membership.id).empty?
          team.update!(deleted_at: Time.current) if orphaning_team

          orphaning_team ? membership.delete : membership.destroy!
        end

        user = current_user
        end_session!
        user.destroy!

        head :no_content
      end
    end
  end
end
