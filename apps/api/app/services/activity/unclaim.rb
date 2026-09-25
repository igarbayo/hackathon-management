# "Not mine" (RF-ACT-018, ADR-0018): leaves GitHub events with no user. The
# member who had them is kept in actor.unclaimed_by, so automatic assignment
# does not give them back, and their identities are removed from their
# git_identities. A member only on their own events; an owner, on any.
module Activity
  class Unclaim
    def self.call(team:, by:, events:)
      new(team: team, by: by, events: events).call
    end

    def initialize(team:, by:, events:)
      @team = team
      @by = by
      @events = events
    end

    # Returns [unassigned events, number skipped].
    def call
      allowed = events.select { |event| event.source == "github" && event.actor["membership_id"].present? && (by.owner? || event.actor["membership_id"] == by.id.to_s) }

      allowed.group_by { |event| event.actor["membership_id"] }.each do |membership_id, holder_events|
        holder = Membership.where(team_id: team.id, id: membership_id).first
        holder_events.each { |event| release(event, membership_id) }
        next unless holder

        identities = holder_events.flat_map { |event| AuthorIdentity.for_event(event) }
        holder.update!(git_identities: holder.git_identities - identities) if (holder.git_identities & identities).any?
      end

      [ allowed.map(&:reload), events.size - allowed.size ]
    end

    private

    attr_reader :team, :by, :events

    def release(event, membership_id)
      actor = event.actor
      event.actor = actor.except("mapped_by").merge(
        "user_id" => nil,
        "membership_id" => nil,
        "display" => actor["author_name"] || actor["github_login"] || actor["email"],
        "unclaimed_by" => (Array(actor["unclaimed_by"]) + [ membership_id ]).uniq
      )
      event.save!
    end
  end
end
