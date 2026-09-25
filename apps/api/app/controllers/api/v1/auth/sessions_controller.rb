module Api
  module V1
    module Auth
      class SessionsController < Api::V1::BaseController
        def create
          user = ::Auth::LogIn.call(email: params[:email], password: params[:password], ip: request.remote_ip)
          start_session!(user, request: request)

          render json: MeSerializer.new(user).as_json
        rescue ::Auth::LogIn::InvalidCredentials
          raise ApiError::Unauthenticated.new(message: "wrong email or password")
        end

        def destroy
          end_session!
          head :no_content
        end
      end
    end
  end
end
