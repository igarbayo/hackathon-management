# Account deletion (RF-AUTH-007, RF-SEC-004): deletes the user's personal data.
# What is team history (commits, pushes, PRs) stays, but with the actor
# anonymized as "Deleted user" + GitHub login (without the email or author name
# that RF-GH-024 stores).
module Accounts
  class Destroy
    DELETED_DISPLAY = "Deleted user"

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

    # It is an operation centered on the person, like the rest of MeController,
    # but domain queries are still scoped to their teams (RNF-SEC-001).
    def team_ids
      @team_ids ||= memberships.map(&:team_id)
    end

    def ensure_no_team_left_without_owner!
      memberships.each do |membership|
        next unless membership.owner?

        others = Membership.where(team_id: membership.team_id).where(:id.ne => membership.id)
        next if others.where(role: "owner").exists? || !others.exists?

        raise ApiError::Conflict.new(
          message: "you are the only owner of \"#{membership.team.name}\" and it has more members: " \
                   "hand over ownership before deleting the account"
        )
      end
    end

    # Without its membership, a PAT or an OAuth token would no longer be tied to
    # a person (Tracking::RecordApiChange would treat it as an integration), so
    # all of them are revoked. Integration tokens belong to the team and stay.
    def revoke_tokens
      AccessToken.where(revoked_at: nil, :team_id.in => team_ids)
                 .any_of({ user_id: user.id }, { :membership_id.in => membership_ids })
                 .not_in(kind: %w[integration])
                 .update_all(revoked_at: Time.current, revoke_reason: "account_deleted")
    end

    # Like "Disconnect and delete my events" (Cli::RevokeLink), in all their teams.
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
        "actor.display" => DELETED_DISPLAY,
        "actor.email" => nil,
        "actor.author_name" => nil
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
