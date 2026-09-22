module Api
  module V1
    class TeamsController < Api::V1::BaseController
      include TeamScoping

      skip_before_action :load_team_and_membership, only: %i[create join]
      session_only :create, :join, :update, :rotate_code, :destroy
      requires_scope "read", only: :show

      def create
        hackathon_params = params.require(:hackathon).permit(:name, :starts_at, :ends_at, :timezone, :url, :challenge_text)
        team = ::Teams::Create.call(owner: current_user, name: params[:name], hackathon: hackathon_params.to_h)

        render json: TeamSerializer.new(team).as_json, status: :created
      end

      def join
        _team, membership = ::Teams::Join.call(user: current_user, code: params[:code])

        render json: { team_id: membership.team_id.to_s, role: membership.role }, status: :ok
      end

      def show
        render json: TeamSerializer.new(current_team).as_json
      end

      def update
        require_owner!

        hackathon_params = params[:hackathon].present? ? params.require(:hackathon).permit(:name, :starts_at, :ends_at, :timezone, :url, :challenge_text) : nil
        attrs = params.permit(:name, settings: {}).to_h.compact_blank

        current_team.assign_attributes(attrs)
        current_team.hackathon.assign_attributes(hackathon_params.to_h) if hackathon_params
        current_team.save!

        render json: TeamSerializer.new(current_team).as_json
      end

      def rotate_code
        require_owner!
        current_team.regenerate_code!

        render json: TeamSerializer.new(current_team).as_json
      end

      def destroy
        require_owner!

        unless params[:confirm_name] == current_team.name
          raise ApiError::BadRequest.new(message: "hay que escribir el nombre del equipo para confirmar")
        end

        current_team.update!(deleted_at: Time.current)
        head :no_content
      end
    end
  end
end
