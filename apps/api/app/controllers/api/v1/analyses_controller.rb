module Api
  module V1
    class AnalysesController < Api::V1::BaseController
      include TeamScoping

      def index
        analyses = AiAnalysis.where(team_id: current_team.id).order(created_at: :desc).limit(50)
        render json: { data: analyses.map { |a| AiAnalysisSerializer.new(a, include_result: false).as_json } }
      end

      def latest
        analysis = AiAnalysis.where(team_id: current_team.id, status: "succeeded").order(created_at: :desc).first
        alerts_now = Analysis::DeterministicAlerts.call(current_team)

        render json: {
          analysis: analysis && AiAnalysisSerializer.new(analysis).as_json,
          deterministic_alerts: alerts_now
        }
      end

      def show
        analysis = find_analysis
        render json: AiAnalysisSerializer.new(analysis).as_json
      end

      def create
        Analysis::Quota.check_manual!(current_team)

        analysis = Analysis::Enqueue.call(team: current_team, trigger: "manual", requested_by: current_user)

        render json: AiAnalysisSerializer.new(analysis, include_result: false).as_json, status: :accepted
      rescue Analysis::Quota::ExceededError => e
        response.headers["Retry-After"] = e.retry_after.to_i.to_s
        raise ApiError.new(status: :too_many_requests, code: "rate_limited", message: e.message)
      end

      private

      def find_analysis
        AiAnalysis.where(team_id: current_team.id, id: params[:id]).first.tap do |analysis|
          raise ApiError::NotFound.new(message: "análisis no encontrado") unless analysis
        end
      end
    end
  end
end
