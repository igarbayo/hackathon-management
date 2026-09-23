module Teams
  class Create
    def self.call(owner:, name:, hackathon:)
      team = Team.new(name: name)
      team.build_hackathon(hackathon)
      team.save!

      Membership.create!(team: team, user: owner, role: "owner")
      owner.remember_last_team!(team.id)

      team
    end
  end
end
