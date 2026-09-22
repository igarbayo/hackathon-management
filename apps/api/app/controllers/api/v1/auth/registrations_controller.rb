module Api
  module V1
    module Auth
      class RegistrationsController < Api::V1::BaseController
        def create
          user = ::Auth::SignUp.call(
            email: params[:email],
            name: params[:name],
            password: params[:password],
            ip: request.remote_ip
          )
          start_session!(user, request: request)

          render json: MeSerializer.new(user).as_json, status: :created
        end
      end
    end
  end
end
