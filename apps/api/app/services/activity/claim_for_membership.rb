# Retroactive assignment (07-integracion-github.md#mapeo-de-autores): gives a
# member the GitHub events of their team that still have no user and whose
# author matches one of their identities. It never takes an event from anyone or
# gives back the ones that member marked as "Not mine".
module Activity
  class ClaimForMembership
    def self.call(membership, mapped_by: "auto", identities: nil)
      new(membership, mapped_by: mapped_by, identities: identities).call
    end

    def initialize(membership, mapped_by:, identities:)
      @membership = membership
      @mapped_by = mapped_by
      @identities = identities || AuthorIdentity.for_membership(membership)
    end

    # Returns how many events were assigned.
    def call
      conditions = AuthorIdentity.event_conditions(identities)
      return 0 if conditions.empty?

      scope = ActivityEvent.where(team_id: membership.team_id, source: "github", "actor.user_id" => nil)
                           .where("actor.unclaimed_by" => { "$ne" => membership.id.to_s })
                           .any_of(*conditions)

      scope.update_all("$set" => {
        "actor.user_id" => membership.user_id.to_s,
        "actor.membership_id" => membership.id.to_s,
        "actor.display" => membership.display_name,
        "actor.mapped_by" => mapped_by
      }).modified_count
    end

    private

    attr_reader :membership, :mapped_by, :identities
  end
end
