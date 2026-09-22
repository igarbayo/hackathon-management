# POST /cli/device y /cli/device/token (RF-CC-001). Sin sesión ni Bearer:
# no hereda de Api::V1::BaseController para no exigir X-CSRF-Token, que el
# CLI no tiene forma de obtener (RNF-SEC-003 solo pide CSRF en endpoints de
# sesión).
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
