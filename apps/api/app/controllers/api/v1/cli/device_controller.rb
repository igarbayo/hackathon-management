# POST /cli/device and /cli/device/token (RF-CC-001). No session or Bearer: it
# does not inherit from Api::V1::BaseController so it does not require
# X-CSRF-Token, which the CLI has no way to get (RNF-SEC-003 only asks for CSRF
# on session endpoints).
module Api
  module V1
    module Cli
      class DeviceController < ApplicationController
        def create
          result = ::Cli::CreateDeviceAuthorization.call(team_code: params[:team_code])

          render json: {
            device_code: result.device_code,
            user_code: result.record.formatted_user_code,
            verification_url: "#{ENV.fetch('APP_URL', '')}/cli/device?user_code=#{result.record.formatted_user_code}",
            expires_in: (result.record.expires_at - Time.current).to_i,
            interval: 5
          }, status: :created
        end

        def token
          result = ::Cli::ExchangeDeviceToken.call(device_code: params[:device_code])

          case result.outcome
          when :ok
            render json: {
              token: result.token,
              team: { id: result.team.id.to_s, name: result.team.name, code: result.team.code },
              member: { id: result.membership.id.to_s, display_name: result.membership.display_name }
            }
          else
            render json: { error: result.outcome.to_s }, status: :bad_request
          end
        end
      end
    end
  end
end
