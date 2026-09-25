# Runs Activity::ClaimForMembership when a membership is created, when the
# person's GitHub login or email changes, or when git_identities are added
# (07-integracion-github.md#mapeo-de-autores). Idempotent.
module Activity
  class ClaimForMembershipJob
    include Sidekiq::Job
    sidekiq_options queue: "attribution"

    def perform(membership_id)
      membership = Membership.where(id: membership_id).first
      return unless membership

      Activity::ClaimForMembership.call(membership)
    end
  end
end
