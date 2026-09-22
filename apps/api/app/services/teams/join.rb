module Teams
  class Join
    def self.call(user:, code:)
      team = Team.active.where(code: code.to_s.upcase.delete("-")).first
      raise ApiError::NotFound.new(message: "código de equipo no válido") unless team

      RateLimiter.check!("team_join:#{user.id}", limit: 20, period: 1.hour)

      membership = Membership.where(team_id: team.id, user_id: user.id).first
      membership ||= Membership.create!(team: team, user: user, role: "member")

      [team, membership]
    end
  end
end
