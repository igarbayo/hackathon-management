module Api
  module V1
    module Auth
      class GithubController < Api::V1::BaseController
        skip_before_action :verify_csrf!, only: [ :new, :callback ]

        # Rutas de la web a las que se puede volver tras vincular GitHub.
        LINK_RETURN_PATHS = %w[/onboarding].freeze

        def new
          state = link_requested? ? link_state : OAuthLoginState.generate
          redirect_to ::Auth::GithubLogin.authorize_url(state: state), allow_other_host: true
        end

        def callback
          claims = OAuthLoginState.verify(params[:state]).with_indifferent_access
          return link_callback(claims) if claims[:link_user_id].present?

          user = ::Auth::GithubLogin.call(code: params[:code])
          start_session!(user, request: request)

          redirect_to ENV.fetch("APP_URL", "/"), allow_other_host: true
        rescue ::Auth::GithubLogin::AuthorizationFailed => e
          raise ApiError::Unauthenticated.new(message: e.message)
        end

        private

        def link_requested?
          ActiveModel::Type::Boolean.new.cast(params[:link])
        end

        # RF-TEAM-014: "Vincular GitHub" desde el onboarding, con sesión.
        def link_state
          authenticate_user!
          return_to = LINK_RETURN_PATHS.include?(params[:return_to]) ? params[:return_to] : "/onboarding"
          OAuthLoginState.generate(link_user_id: current_user.id.to_s, return_to: return_to)
        end

        # No abre sesión: la identidad se añade a la cuenta que pidió vincular,
        # que tiene que seguir siendo la de la sesión. El resultado vuelve a la
        # web en `github_link` (linked, taken o error).
        def link_callback(claims)
          result =
            if current_user && current_user.id.to_s == claims[:link_user_id]
              begin
                ::Auth::GithubLogin.link(code: params[:code], user: current_user)
                "linked"
              rescue ::Auth::GithubLogin::IdentityTaken
                "taken"
              rescue ::Auth::GithubLogin::AuthorizationFailed
                "error"
              end
            else
              "error"
            end

          return_to = LINK_RETURN_PATHS.include?(claims[:return_to]) ? claims[:return_to] : "/onboarding"
          redirect_to "#{ENV.fetch('APP_URL', '')}#{return_to}?github_link=#{result}", allow_other_host: true
        end
      end
    end
  end
end
