module Teams
  class Create
    def self.call(owner:, name:, hackathon:)
      team = Team.new(name: name)
      # 04-pantallas.md#onboarding: the start is "now" if not given. Without
      # it, the history import would not know since when to bring commits
      # (RF-GH-023).
      hackathon = hackathon.to_h.with_indifferent_access
      hackathon[:starts_at] = hackathon[:starts_at].presence || Time.current
      team.build_hackathon(hackathon)
      team.save!

      Membership.create!(team: team, user: owner, role: "owner")
      owner.remember_last_team!(team.id)

      team
    end
  end
end
