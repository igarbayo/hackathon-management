# Cascada para resolver actor.user_id en eventos de GitHub
# (07-integracion-github.md#mapeo-de-autores).
module Github
  class MapAuthor
    NOREPLY_PATTERN = /\A\d+\+(?<login>[^@]+)@users\.noreply\.github\.com\z/

    def self.call(team:, login: nil, email: nil, display_name: nil)
      new(team: team, login: login, email: email, display_name: display_name).call
    end

    def initialize(team:, login:, email:, display_name:)
      @team = team
      @login = login
      @email = email
      @display_name = display_name
    end

    def call
      membership = by_login(login) || by_email(email) || by_noreply_email(email)

      if membership
        { "user_id" => membership.user_id.to_s, "membership_id" => membership.id.to_s, "display" => membership.display_name, "github_login" => login }
      else
        { "user_id" => nil, "membership_id" => nil, "display" => display_name || login || email, "github_login" => login }
      end
    end

    private

    attr_reader :team, :login, :email, :display_name

    def by_login(candidate_login)
      return nil if candidate_login.blank?

      user = User.where(github_login: candidate_login).first
      return nil unless user

      Membership.where(team_id: team.id, user_id: user.id).first
    end

    def by_email(candidate_email)
      return nil if candidate_email.blank?

      user = User.where(email: candidate_email.downcase).first
      membership = user && Membership.where(team_id: team.id, user_id: user.id).first
      return membership if membership

      Membership.where(team_id: team.id, git_identities: candidate_email.downcase).first
    end

    def by_noreply_email(candidate_email)
      return nil if candidate_email.blank?

      match = candidate_email.match(NOREPLY_PATTERN)
      return nil unless match

      by_login(match[:login])
    end
  end
end
