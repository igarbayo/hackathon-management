# Cascada para resolver actor.user_id en eventos de GitHub
# (07-integracion-github.md#mapeo-de-autores). Sea o no miembro, el actor
# guarda siempre la identidad del autor (login, email y nombre), para poder
# asignarle el evento cuando se dé de alta (ADR-0018).
module Github
  class MapAuthor
    def self.call(team:, login: nil, email: nil, display_name: nil)
      new(team: team, login: login, email: email, display_name: display_name).call
    end

    def initialize(team:, login:, email:, display_name:)
      @team = team
      @login = login.presence
      @email = Activity::AuthorIdentity.normalize(email)
      @display_name = display_name.presence
    end

    def call
      membership = by_login(login) || by_email(email) || by_login(Activity::AuthorIdentity.login_from_noreply(email))
      author_name = display_name || login || email
      identity = { "github_login" => login, "email" => email, "author_name" => author_name }

      if membership
        identity.merge("user_id" => membership.user_id.to_s, "membership_id" => membership.id.to_s,
                       "display" => membership.display_name, "mapped_by" => "auto")
      else
        identity.merge("user_id" => nil, "membership_id" => nil, "display" => author_name)
      end
    end

    private

    attr_reader :team, :login, :email, :display_name

    def by_login(candidate_login)
      candidate = Activity::AuthorIdentity.normalize(candidate_login)
      return nil unless candidate

      user_ids = User.where(github_login: /\A#{Regexp.escape(candidate)}\z/i).pluck(:id)
      Membership.where(team_id: team.id, :user_id.in => user_ids).first ||
        Membership.where(team_id: team.id, git_identities: candidate).first
    end

    def by_email(candidate_email)
      return nil if candidate_email.blank?

      user = User.where(email: candidate_email).first
      membership = user && Membership.where(team_id: team.id, user_id: user.id).first
      return membership if membership

      Membership.where(team_id: team.id, git_identities: candidate_email).first
    end
  end
end
