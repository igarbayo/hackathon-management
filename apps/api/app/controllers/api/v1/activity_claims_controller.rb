# RF-ACT-018 (ADR-0018): unlinked authors and manual assignment of the author of
# GitHub events ("These are mine", "Assign to…", "Not mine").
module Api
  module V1
    class ActivityClaimsController < Api::V1::BaseController
      include TeamScoping

      # It is the only response with author emails: only for team members on the
      # web app, never for tokens or connected apps (ADR-0018).
      session_only :unlinked_authors
      requires_scope "attribution:write", only: %i[claim unclaim]

      BULK_LIMIT = 100

      def unlinked_authors
        render json: { data: ::Activity::UnlinkedAuthors.call(current_team) }
      end

      def claim
        by = require_personal_membership!
        target = params[:membership_id].present? ? find_membership(params[:membership_id]) : by

        result = ::Activity::Claim.call(
          team: current_team, by: by, target: target,
          events: claim_events(by),
          include_future: ActiveModel::Type::Boolean.new.cast(params[:include_future]) || false
        )

        render json: { data: result.events.map { |e| ActivityEventSerializer.new(e).as_json }, skipped: result.skipped }
      end

      def unclaim
        by = require_personal_membership!
        events, skipped = ::Activity::Unclaim.call(team: current_team, by: by, events: find_events(params[:event_ids]))

        render json: { data: events.map { |e| ActivityEventSerializer.new(e).as_json }, skipped: skipped }
      end

      private

      # An integration token acts as the team, not as a person: there is nobody
      # to assign "mine" to.
      def require_personal_membership!
        current_membership || raise(ApiError::Forbidden.new(message: "you have to act as a team member"))
      end

      def claim_events(by)
        author = params[:author]
        return find_events(params[:event_ids]) if author.blank?

        identities = [ author[:github_login], author[:email] ].filter_map { |i| ::Activity::AuthorIdentity.normalize(i) }
        raise ApiError::BadRequest.new(message: "author needs github_login or email") if identities.empty?

        scope = ActivityEvent.where(team_id: current_team.id, source: "github")
                             .any_of(*::Activity::AuthorIdentity.event_conditions(identities))
        scope = scope.where("actor.user_id" => nil) unless by.owner?
        scope.to_a
      end

      def find_events(ids)
        ids = Array(ids)
        raise ApiError::BadRequest.new(message: "event_ids is required") if ids.empty?
        raise ApiError::BadRequest.new(message: "at most #{BULK_LIMIT} events") if ids.size > BULK_LIMIT

        ActivityEvent.where(team_id: current_team.id, :id.in => ids).to_a
      end

      def find_membership(id)
        Membership.where(team_id: current_team.id, id: id).first.tap do |membership|
          raise ApiError::NotFound.new(message: "member not found") unless membership
        end
      end
    end
  end
end
