# "These are mine" / "Assign to…" (RF-ACT-018, ADR-0018): assigns GitHub events
# to a member by hand. A member can only assign themselves events with no user;
# an owner can assign any event to any member. With include_future, the
# identities of those events are added to the recipient's git_identities so
# their next commits reach them by themselves.
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
      raise ApiError::Forbidden.new(message: "only an owner can assign events to another member") if target.id != by.id && !by.owner?

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

    # 409 identity_taken if any identity already belongs to another member,
    # through their account (login or email) or their git_identities.
    def ensure_identities_free!(identities)
      others = Membership.where(team_id: team.id, :id.ne => target.id).includes(:user)
      taken = identities.select { |identity| others.any? { |member| AuthorIdentity.for_membership(member).include?(identity) } }
      return if taken.empty?

      raise ApiError::Conflict.new(
        message: "#{taken.join(', ')} already belongs to another team member",
        details: { code: "identity_taken", identities: taken }
      )
    end
  end
end
