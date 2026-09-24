# Borrado de cuenta (RF-AUTH-007, RF-SEC-004): elimina los datos personales
# del usuario. Lo que es historia del equipo (commits, pushes, PRs) se queda,
# pero con el actor anonimizado como "Usuario eliminado" + login de GitHub.
module Accounts
  class Destroy
    DELETED_DISPLAY = "Usuario eliminado"

    def self.call(user:)
      new(user).call
    end

    def initialize(user)
      @user = user
      @memberships = Membership.where(user_id: user.id).to_a
    end

    def call
      ensure_no_team_left_without_owner!

      revoke_tokens
      OAuthGrant.where(user_id: user.id, :team_id.in => team_ids).delete_all
      purge_personal_events
      anonymize_remaining_events
      remove_memberships

      user.destroy!
    end

    private

    attr_reader :user, :memberships

    def membership_ids
      @membership_ids ||= memberships.map(&:id)
    end

    # Es una operación centrada en la persona, como el resto de MeController,
    # pero las consultas de dominio siguen acotadas a sus equipos (RNF-SEC-001).
    def team_ids
      @team_ids ||= memberships.map(&:team_id)
    end

    def ensure_no_team_left_without_owner!
      memberships.each do |membership|
        next unless membership.owner?

        others = Membership.where(team_id: membership.team_id).where(:id.ne => membership.id)
        next if others.where(role: "owner").exists? || !others.exists?

        raise ApiError::Conflict.new(
          message: "eres el único owner de \"#{membership.team.name}\" y tiene más miembros: " \
                   "transfiere la propiedad antes de borrar la cuenta"
        )
      end
    end

    # Sin su membresía, un PAT o un token OAuth dejaría de estar ligado a una
    # persona (Tracking::RecordApiChange lo trataría como una integración), así
    # que se revocan todos. Los tokens de integración son del equipo y siguen.
    def revoke_tokens
      AccessToken.where(revoked_at: nil, :team_id.in => team_ids)
                 .any_of({ user_id: user.id }, { :membership_id.in => membership_ids })
                 .not_in(kind: %w[integration])
                 .update_all(revoked_at: Time.current, revoke_reason: "account_deleted")
    end

    # Como "Desconectar y borrar mis eventos" (Cli::RevokeLink), en todos sus equipos.
    def purge_personal_events
      ActivityEvent.where(:team_id.in => team_ids)
                   .any_in("actor.membership_id" => membership_ids.map(&:to_s))
                   .any_in(source: %w[claude_code mcp])
                   .delete_all
    end

    def anonymize_remaining_events
      ActivityEvent.where(:team_id.in => team_ids, "actor.user_id" => user.id.to_s).update_all(
        "actor.user_id" => nil,
        "actor.membership_id" => nil,
        "actor.display" => DELETED_DISPLAY
      )
    end

    def remove_memberships
      memberships.each do |membership|
        team = membership.team
        orphaning_team = membership.owner? && Membership.where(team_id: team.id).where(:id.ne => membership.id).empty?
        team.soft_delete! if orphaning_team

        orphaning_team ? membership.delete : membership.destroy!
      end
    end
  end
end
