module Api
  module V1
    module Auth
      class GithubController < Api::V1::BaseController
        skip_before_action :verify_csrf!, only: [:new, :callback]

        def new
          state = OAuthLoginState.generate
          redirect_to ::Auth::GithubLogin.authorize_url(state: state), allow_other_host: true
        end

        def callback
          OAuthLoginState.verify(params[:state])
          user = ::Auth::GithubLogin.call(code: params[:code])
          start_session!(user, request: request)

          redirect_to ENV.fetch("APP_URL", "/"), allow_other_host: true
        rescue ::Auth::GithubLogin::AuthorizationFailed => e
          raise ApiError::Unauthenticated.new(message: e.message)
        end
      end
    end
  end
end
