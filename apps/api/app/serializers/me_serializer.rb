# RF-AUTH-005: user, memberships (team and role) and last_team_id.
class MeSerializer
  def initialize(user)
    @user = user
  end

  def as_json
    {
      id: user.id.to_s,
      email: user.email,
      name: user.name,
      avatar_url: user.avatar_url,
      github_login: user.github_login,
      has_password: user.password_digest.present?,
      gemini_api_key_configured: user.gemini_api_key_configured?,
      last_team_id: user.last_team_id&.to_s,
      memberships: memberships
    }
  end

  private

  attr_reader :user

  def memberships
    Membership.where(user_id: user.id).map do |membership|
      {
        team_id: membership.team_id.to_s,
        team_name: membership.team&.name,
        role: membership.role
      }
    end
  end
end
