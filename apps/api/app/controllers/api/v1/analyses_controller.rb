module Api
  module V1
    class AnalysesController < Api::V1::BaseController
      include TeamScoping

      requires_scope "read", only: %i[index latest show]
      requires_scope "analyses:run", only: :create

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

        # current_user es nil con un token de integración (actúa como la
        # integración, no como una persona): RunJob cae entonces a la clave
        # del owner del equipo, igual que un análisis programado.
        if current_user && current_user.gemini_api_key.blank?
          raise ApiError.new(
            status: :unprocessable_entity, code: "missing_gemini_api_key",
            message: "Configura tu clave de Gemini en tu perfil (Ajustes) para poder analizar."
          )
        end

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
