# Identidad de GitHub del autor de un evento y de un miembro del equipo
# (07-integracion-github.md#mapeo-de-autores, ADR-0018). Los logins y los
# emails se comparan siempre en minúsculas.
module Activity
  module AuthorIdentity
    NOREPLY_PATTERN = /\A\d+\+(?<login>[^@]+)@users\.noreply\.github\.com\z/i

    module_function

    def normalize(value)
      value.to_s.strip.downcase.presence
    end

    def email?(identity)
      identity.to_s.include?("@")
    end

    def login_from_noreply(email)
      match = email.to_s.match(NOREPLY_PATTERN)
      match && match[:login].downcase
    end

    # Identidades de un evento: su login y su email (si los tiene).
    def for_event(event)
      actor = event.actor || {}
      [ normalize(actor["github_login"]), normalize(actor["email"]) ].compact
    end

    # Logins y emails con los que se reconoce a un miembro: los de su cuenta
    # y los de sus git_identities.
    def for_membership(membership)
      user = membership.user
      identities = [ normalize(user&.github_login), normalize(user&.email) ] + Array(membership.git_identities).map { |i| normalize(i) }
      identities.compact.uniq
    end

    # Criterio de Mongo para los eventos cuyo autor tiene alguna de estas
    # identidades (login exacto sin mayúsculas, email exacto o email noreply
    # con ese login).
    def event_conditions(identities)
      identities.flat_map do |identity|
        if email?(identity)
          [ { "actor.email" => identity } ]
        else
          escaped = Regexp.escape(identity)
          [
            { "actor.github_login" => /\A#{escaped}\z/i },
            { "actor.email" => /\A\d+\+#{escaped}@users\.noreply\.github\.com\z/i }
          ]
        end
      end
    end
  end
end
