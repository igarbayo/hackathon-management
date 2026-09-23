# "Son míos" / "Asignar a…" (RF-ACT-018, ADR-0018): asigna eventos de GitHub
# a un miembro a mano. Un miembro solo puede asignarse eventos sin usuario; un
# owner puede asignar cualquiera a cualquier miembro. Con include_future, las
# identidades de esos eventos pasan a git_identities del destinatario para
# que sus commits siguientes le lleguen solos.
module Activity
  class Claim
    Result = Struct.new(:events, :skipped, keyword_init: true)

    def self.call(**args)
      new(**args).call
    end

    def initialize(team:, by:, target:, events:, include_future:)
      @team = team
      @by = by
      @target = target
      @events = events
      @include_future = include_future
    end

    def call
      raise ApiError::Forbidden.new(message: "solo un owner puede asignar eventos a otro miembro") if target.id != by.id && !by.owner?

      github_events = events.select { |event| event.source == "github" }
      allowed = github_events.select { |event| by.owner? || event.actor["user_id"].blank? }

      if include_future
        new_identities = allowed.flat_map { |event| AuthorIdentity.for_event(event) }.uniq - AuthorIdentity.for_membership(target)
        ensure_identities_free!(new_identities)
        target.update!(git_identities: target.git_identities + new_identities) if new_identities.any?
      end

      allowed.each { |event| assign(event) }
      ClaimForMembership.call(target) if include_future

      Result.new(events: allowed.map(&:reload), skipped: events.size - allowed.size)
    end

    private

    attr_reader :team, :by, :target, :events, :include_future

    def assign(event)
      event.actor = event.actor.merge(
        "user_id" => target.user_id.to_s,
        "membership_id" => target.id.to_s,
        "display" => target.display_name,
        "mapped_by" => "manual",
        "unclaimed_by" => Array(event.actor["unclaimed_by"]) - [ target.id.to_s ]
      )
      event.save!
    end

    # 409 identity_taken si alguna identidad ya es de otro miembro, por su
    # cuenta (login o email) o por sus git_identities.
    def ensure_identities_free!(identities)
      others = Membership.where(team_id: team.id, :id.ne => target.id).includes(:user)
      taken = identities.select { |identity| others.any? { |member| AuthorIdentity.for_membership(member).include?(identity) } }
      return if taken.empty?

      raise ApiError::Conflict.new(
        message: "#{taken.join(', ')} ya es de otro miembro del equipo",
        details: { code: "identity_taken", identities: taken }
      )
    end
  end
end
