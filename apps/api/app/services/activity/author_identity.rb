# GitHub identity of an event's author and of a team member
# (07-integracion-github.md#mapeo-de-autores, ADR-0018). Logins and emails are
# always compared in lowercase.
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

    # Identities of an event: its login and its email (if it has them).
    def for_event(event)
      actor = event.actor || {}
      [ normalize(actor["github_login"]), normalize(actor["email"]) ].compact
    end

    # Logins and emails a member is recognized by: those of their account and
    # those of their git_identities.
    def for_membership(membership)
      user = membership.user
      identities = [ normalize(user&.github_login), normalize(user&.email) ] + Array(membership.git_identities).map { |i| normalize(i) }
      identities.compact.uniq
    end

    # A GitHub event the member holds and whose login is the one of their own
    # GitHub account (RF-ACT-018): it is theirs for sure, so they can neither
    # say "Not mine" about it nor give it to someone else.
    def own_github_login?(event, membership)
      login = normalize(membership.user&.github_login)
      login.present? && event.actor["membership_id"] == membership.id.to_s &&
        normalize(event.actor["github_login"]) == login
    end

    # Mongo criteria for the events whose author has any of these identities
    # (exact case-insensitive login, exact email or a noreply email with that
    # login).
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
