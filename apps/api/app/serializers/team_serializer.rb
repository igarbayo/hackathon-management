class TeamSerializer
  def initialize(team)
    @team = team
  end

  def as_json
    {
      id: team.id.to_s,
      name: team.name,
      code: team.code,
      formatted_code: team.formatted_code,
      plan: team.plan,
      settings: team.settings,
      hackathon: hackathon_json,
      created_at: team.created_at.iso8601
    }
  end

  private

  attr_reader :team

  def hackathon_json
    return nil unless team.hackathon

    {
      name: team.hackathon.name,
      starts_at: team.hackathon.starts_at&.iso8601,
      ends_at: team.hackathon.ends_at&.iso8601,
      timezone: team.hackathon.timezone,
      url: team.hackathon.url,
      challenge_text: team.hackathon.challenge_text
    }
  end
end
