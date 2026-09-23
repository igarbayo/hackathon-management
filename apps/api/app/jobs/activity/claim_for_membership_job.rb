# Lanza Activity::ClaimForMembership al crear una membresía, al cambiar el
# login de GitHub o el email de la persona, o al añadir git_identities
# (07-integracion-github.md#mapeo-de-autores). Idempotente.
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
