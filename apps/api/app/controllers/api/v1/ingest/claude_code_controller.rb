# POST /api/v1/ingest/claude_code (RF-CC-004). Bearer hb_mt_: it does not
# inherit from Api::V1::BaseController so it does not require CSRF (RNF-SEC-003
# limits it to session endpoints; the CLI has no cookie).
module Api
  module V1
    module Ingest
      class ClaudeCodeController < ApplicationController
        include TokenAuthentication
        before_action :authenticate_member_token!
        before_action :enforce_rate_limit!

        # RNF-SEC-005 (03-api.md#contrato-de-ingesta): 120 requests per minute
        # per token. The schema already limits each request to 200 events
        # (maxItems).
        RATE_LIMIT = 120
        RATE_PERIOD = 1.minute

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

        private

        def enforce_rate_limit!
          RateLimiter.check!("ingest:#{current_membership.id}", limit: RATE_LIMIT, period: RATE_PERIOD)
        end
      end
    end
  end
end
