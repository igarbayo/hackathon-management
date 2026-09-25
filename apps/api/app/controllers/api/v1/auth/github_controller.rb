module Api
  module V1
    module Auth
      class GithubController < Api::V1::BaseController
        skip_before_action :verify_csrf!, only: [ :new, :callback ]

        # After linking GitHub the only way back is the onboarding, keeping the
        # invite code if there was one (RF-TEAM-014).
        LINK_RETURN_PATH = "/onboarding"
        TEAM_CODE = /\A[A-Za-z0-9-]{1,20}\z/

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

        # RF-TEAM-014: "Link GitHub" from the onboarding, with a session.
        def link_state
          authenticate_user!
          OAuthLoginState.generate(link_user_id: current_user.id.to_s, return_to: safe_return_to(params[:return_to]))
        end

        # It does not sign in: the identity is added to the account that asked
        # to link it, which must still be the session's account. The result
        # goes back to the web in `github_link` (linked, taken or error).
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

          return_to = safe_return_to(claims[:return_to])
          separator = return_to.include?("?") ? "&" : "?"
          redirect_to "#{ENV.fetch('APP_URL', '')}#{return_to}#{separator}github_link=#{result}", allow_other_host: true
        end

        # Only `/onboarding`, with `code` as the only parameter and shaped like a
        # team code; anything else goes back to plain `/onboarding`.
        def safe_return_to(value)
          uri = URI.parse(value.to_s)
          return LINK_RETURN_PATH unless uri.path == LINK_RETURN_PATH && uri.host.nil? && uri.scheme.nil?

          query = Rack::Utils.parse_query(uri.query.to_s)
          code = query["code"]
          return LINK_RETURN_PATH unless query.keys == [ "code" ] && code.is_a?(String) && code.match?(TEAM_CODE)

          "#{LINK_RETURN_PATH}?code=#{code}"
        rescue URI::InvalidURIError
          LINK_RETURN_PATH
        end
      end
    end
  end
end
