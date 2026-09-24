# RF-ACT-018 (ADR-0018): autores sin vincular y asignación manual del autor
# de eventos de GitHub ("Son míos", "Asignar a…", "No son míos").
module Api
  module V1
    class ActivityClaimsController < Api::V1::BaseController
      include TeamScoping

      # Es la única respuesta con emails de autores: solo para personas del
      # equipo en la web, nunca para tokens ni apps conectadas (ADR-0018).
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

      # Un token de integración actúa como el equipo, no como una persona:
      # no tiene a quién asignar "míos".
      def require_personal_membership!
        current_membership || raise(ApiError::Forbidden.new(message: "hace falta actuar como un miembro del equipo"))
      end

      def claim_events(by)
        author = params[:author]
        return find_events(params[:event_ids]) if author.blank?

        identities = [ author[:github_login], author[:email] ].filter_map { |i| ::Activity::AuthorIdentity.normalize(i) }
        raise ApiError::BadRequest.new(message: "author necesita github_login o email") if identities.empty?

        scope = ActivityEvent.where(team_id: current_team.id, source: "github")
                             .any_of(*::Activity::AuthorIdentity.event_conditions(identities))
        scope = scope.where("actor.user_id" => nil) unless by.owner?
        scope.to_a
      end

      def find_events(ids)
        ids = Array(ids)
        raise ApiError::BadRequest.new(message: "event_ids es obligatorio") if ids.empty?
        raise ApiError::BadRequest.new(message: "máximo #{BULK_LIMIT} eventos") if ids.size > BULK_LIMIT

        ActivityEvent.where(team_id: current_team.id, :id.in => ids).to_a
      end

      def find_membership(id)
        Membership.where(team_id: current_team.id, id: id).first.tap do |membership|
          raise ApiError::NotFound.new(message: "miembro no encontrado") unless membership
        end
      end
    end
  end
end
