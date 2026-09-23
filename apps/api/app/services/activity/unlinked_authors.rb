# Autores de eventos de GitHub sin usuario (RF-ACT-018), agrupados por login
# o, si el evento no lo trae, por email. Es la única respuesta de la API que
# expone emails de autores, y solo a miembros del equipo (ADR-0018).
module Activity
  class UnlinkedAuthors
    SCAN_LIMIT = 5_000

    def self.call(team)
      events = ActivityEvent.where(team_id: team.id, source: "github", "actor.user_id" => nil)
                            .order(occurred_at: :desc).limit(SCAN_LIMIT).only(:actor, :occurred_at)

      groups = events.group_by do |event|
        login = AuthorIdentity.normalize(event.actor["github_login"])
        login ? "login:#{login}" : "email:#{AuthorIdentity.normalize(event.actor['email'])}"
      end

      groups.map do |_key, author_events|
        latest = author_events.first
        {
          github_login: author_events.filter_map { |e| e.actor["github_login"] }.first,
          email: author_events.filter_map { |e| e.actor["email"] }.first,
          author_name: latest.actor["author_name"] || latest.actor["display"],
          event_count: author_events.size,
          last_event_at: latest.occurred_at.iso8601
        }
      end.sort_by { |author| -author[:event_count] }
    end
  end
end
