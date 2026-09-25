# RF-GH-023: al vincular un repo se importa el histórico reciente. Alcance:
# los commits de las ramas activas desde hackathon.starts_at (máx. 1000 en
# total, de hasta 50 ramas) y los PRs abiertos. RNF-GH-003: también sirve para "Resincronizar".
# RF-GH-025: el resultado queda en repository.last_import.
module Github
  class ImportHistoryJob
    include Sidekiq::Job
    sidekiq_options queue: "github", retry: 3

    MAX_COMMITS = 1000
    # RNF-GH-002: las stats de cada commit son una petición más a GitHub. Se
    # reparten a este ritmo (1800/h, un 36 % del cupo de 5000/h) para dejar
    # sitio a webhooks y otras importaciones; RateBudget corta al 80 %.
    STATS_PER_MINUTE = 30
    # Tope de ramas por importación: cada rama es al menos una petición a
    # GitHub (RNF-GH-002).
    MAX_BRANCHES = 50

    # Encola la importación y la marca como pendiente, para que la interfaz
    # no muestre el resultado de la anterior mientras tanto.
    def self.enqueue(repository)
      repository.set(last_import: { "status" => "queued" })
      perform_async(repository.id.to_s)
    end

    def perform(repository_id)
      repository = ::Repository.where(id: repository_id).first
      return unless repository

      team = ::Team.where(id: repository.team_id).first
      return unless team

      repository.set(last_import: { "status" => "running" })
      since = team.hackathon&.starts_at

      client = Github::Client.new(repository.installation_id)
      commits, branches = since ? import_commits(client, team, repository, since) : [ 0, 0 ]
      pull_requests = import_open_pull_requests(client, team, repository)

      repository.set(last_import: {
        "status" => "done", "commits" => commits, "branches" => branches, "pull_requests" => pull_requests,
        "since" => since&.utc&.iso8601, "reason" => (since ? nil : "no_starts_at"),
        "finished_at" => Time.current.utc.iso8601
      }.compact)
    rescue Github::Client::RateLimited => e
      repository&.set(last_import: { "status" => "queued" })
      self.class.perform_at(e.reset_at, repository_id)
    rescue StandardError
      repository&.set(last_import: { "status" => "failed", "finished_at" => Time.current.utc.iso8601 })
      raise
    end

    private

    # RF-GH-023/026: recorre las ramas activas (las que tienen commits desde
    # `since`) y crea un evento por commit, con todas las ramas en las que
    # está. Las ramas que no son la por defecto van primero, para que
    # `branch` sea la rama de trabajo y la atribución por rama funcione.
    # Devuelve [commits, ramas activas], estén ya importados o no: es lo que
    # se enseña al usuario.
    def import_commits(client, team, repository, since)
      commits_by_sha = {}
      branches_by_sha = Hash.new { |h, k| h[k] = [] }
      active_branches = 0

      branch_names(client, repository).each do |branch|
        commits = branch_commits(client, repository, branch, since)
        active_branches += 1 if commits.any?
        commits.each do |commit|
          commits_by_sha[commit["sha"]] ||= commit
          branches_by_sha[commit["sha"]] << branch
        end
      end

      newest = commits_by_sha.values.sort_by { |c| c.dig("commit", "author", "date").to_s }.reverse.first(MAX_COMMITS)
      stats_enqueued = 0
      newest.each do |commit|
        created = import_commit(team, repository, commit, branches_by_sha[commit["sha"]])
        next unless created

        delay = (stats_enqueued / STATS_PER_MINUTE).minutes
        Github::FetchCommitStatsJob.perform_in(delay, team.id.to_s, repository.id.to_s, commit["sha"])
        stats_enqueued += 1
      end

      [ newest.size, active_branches ]
    end

    # Una rama borrada entre listarla y pedir sus commits se salta.
    def branch_commits(client, repository, branch, since)
      client.get_commits(repository.full_name, sha: branch, since: since)
    rescue Github::Client::NotFound
      []
    end

    def branch_names(client, repository)
      names = client.branches(repository.full_name).map { |b| b["name"] }
      others = (names - [ repository.default_branch ]).first(MAX_BRANCHES - 1)
      others + [ repository.default_branch ].compact
    end

    # true si crea el evento; si ya existía solo le añade las ramas.
    def import_commit(team, repository, commit, branches)
      dedupe_key = "gh:commit:#{commit['sha']}"
      existing = ActivityEvent.where(team_id: team.id, dedupe_key: dedupe_key).first
      if existing
        existing.add_to_set(branches: existing.all_branches + branches)
        return false
      end

      message = commit.dig("commit", "message").to_s
      first_line, *rest = message.split("\n", 2)

      actor = Github::MapAuthor.call(
        team: team,
        login: commit.dig("author", "login"),
        email: commit.dig("commit", "author", "email"),
        display_name: commit.dig("commit", "author", "name")
      )

      ActivityEvent.create!(
        team_id: team.id, source: "github", kind: "commit", dedupe_key: dedupe_key,
        occurred_at: Time.parse(commit.dig("commit", "author", "date")),
        actor: actor, repository_id: repository.id, branch: branches.first, branches: branches, sha: commit["sha"],
        url: commit["html_url"], title: first_line.to_s.first(200),
        payload: { "message_body" => rest.first.to_s.first(1000) }
      )
      true
    end

    def import_open_pull_requests(client, team, repository)
      pull_requests = client.pull_requests(repository.full_name, state: "open")

      pull_requests.each do |pr|
        dedupe_key = "gh:pr:#{pr['number']}:pr_opened"
        next if ActivityEvent.where(team_id: team.id, dedupe_key: dedupe_key).exists?

        actor = Github::MapAuthor.call(team: team, login: pr.dig("user", "login"), email: nil, display_name: nil)

        event = ActivityEvent.create!(
          team_id: team.id, source: "github", kind: "pr_opened", dedupe_key: dedupe_key,
          occurred_at: Time.parse(pr["created_at"]), actor: actor, repository_id: repository.id,
          branch: pr.dig("head", "ref"), pr_number: pr["number"], url: pr["html_url"], title: pr["title"].to_s.first(200)
        )

        Github::FetchPullRequestFilesJob.perform_async(team.id.to_s, repository.id.to_s, event.id.to_s, pr["number"])
      end

      pull_requests.size
    end
  end
end
