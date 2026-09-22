module Api
  module V1
    class ActivityController < Api::V1::BaseController
      include TeamScoping

      requires_scope "read", only: %i[index summary]

      MAX_LIMIT = 100
      DEFAULT_LIMIT = 50

      def index
        scope = ActivityEvent.where(team_id: current_team.id)
        scope = apply_filters(scope)

        limit = [ [ params[:limit].to_i, 1 ].max, MAX_LIMIT ].min
        limit = DEFAULT_LIMIT if params[:limit].blank?

        records, next_cursor = CursorPage.apply(scope, cursor: params[:cursor], limit: limit)

        render json: { data: records.map { |e| ActivityEventSerializer.new(e).as_json }, next_cursor: next_cursor }
      end

      def summary
        window = parse_window(params[:window])
        since = window.ago

        events = ActivityEvent.where(team_id: current_team.id, :occurred_at.gte => since).to_a

        by_person = events.group_by { |e| e.actor["user_id"] }.transform_values(&:size)
        by_feature = events.select { |e| e.attribution&.feature_id }
                            .group_by { |e| e.attribution.feature_id.to_s }
                            .transform_values(&:size)

        render json: { window: params[:window] || "24h", by_person: by_person, by_feature: by_feature, total: events.size }
      end

      private

      def apply_filters(scope)
        scope = scope.where("actor.user_id" => BSON::ObjectId.from_string(params[:user_id])) if params[:user_id].present?
        scope = scope.where("attribution.feature_id" => BSON::ObjectId.from_string(params[:feature_id])) if params[:feature_id].present?
        scope = scope.where(source: params[:source]) if params[:source].present?
        scope = scope.where(kind: params[:kind]) if params[:kind].present?
        scope = apply_attribution_status_filter(scope) if params[:attribution_status].present?
        scope = apply_via_filter(scope) if params[:via].present?
        scope = scope.where("via.token_id" => BSON::ObjectId.from_string(params[:token_id])) if params[:token_id].present?
        scope = scope.where(:occurred_at.gte => Time.iso8601(params[:since])) if params[:since].present?
        scope = scope.where(:occurred_at.lte => Time.iso8601(params[:until])) if params[:until].present?
        scope
      end

      def apply_attribution_status_filter(scope)
        case params[:attribution_status]
        when "none" then scope.where(attribution: nil)
        when "confirmed", "suggested" then scope.where("attribution.status" => params[:attribution_status])
        else scope
        end
      end

      def apply_via_filter(scope)
        case params[:via]
        when "web" then scope.where(via: nil)
        when "api", "mcp" then scope.where("via.channel" => params[:via])
        else scope
        end
      end

      def parse_window(raw)
        case raw
        when "12h" then 12.hours
        when "all" then 100.years
        else 24.hours
        end
      end
    end
  end
end
