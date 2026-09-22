# POST /api/v1/ingest/claude_code (RF-CC-004). Bearer hb_mt_: no hereda de
# Api::V1::BaseController para no exigir CSRF (RNF-SEC-003 lo limita a
# endpoints de sesión; el CLI no tiene cookie).
module Api
  module V1
    module Ingest
      class ClaudeCodeController < ApplicationController
        include TokenAuthentication
        before_action :authenticate_member_token!

        def create
          events = Array(params[:events]).map { |e| e.to_unsafe_h.as_json }

          result = ::Ingest::ProcessBatch.call(
            team: current_team,
            membership: current_membership,
            cli_version: params[:cli_version].to_s,
            events: events
          )

          render json: result.as_json
        end
      end
    end
  end
end
