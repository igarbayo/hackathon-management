module Api
  module V1
    class MeController < Api::V1::BaseController
      before_action :authenticate_user!

      def show
        render json: MeSerializer.new(current_user).as_json
      end

      def update
        attrs = params.permit(:name, :password).to_h.compact_blank
        current_user.assign_attributes(attrs)

        # RF-AI-021: clave personal de Gemini. A diferencia de name/password,
        # se acepta explícitamente vacía para poder quitarla.
        current_user.gemini_api_key = params[:gemini_api_key].presence if params.key?(:gemini_api_key)

        current_user.save!

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
        # Antes de cerrar la sesión: si el borrado falla (409), el usuario sigue dentro.
        ::Accounts::Destroy.call(user: current_user)
        end_session!

        head :no_content
      end
    end
  end
end
