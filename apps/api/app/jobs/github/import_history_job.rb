# RF-GH-023: linking a repo imports its recent history. Scope: commits on the
# active branches since hackathon.starts_at (max. 1000 in total, from up to 50
# branches) and open PRs. RNF-GH-003: it is also used for "Resync".
# RF-GH-025: the result is stored in repository.last_import.
module Github
  class ImportHistoryJob
    include Sidekiq::Job
    sidekiq_options queue: "github", retry: 3

    MAX_COMMITS = 1000
    # RNF-GH-002: each commit's stats are one more request to GitHub. They are
    # spread at this rate (1800/h, 36% of the 5000/h quota) to leave room for
    # webhooks and other imports; RateBudget stops at 80%.
    STATS_PER_MINUTE = 30
    # Max. branches per import: each branch is at least one request to GitHub
    # (RNF-GH-002).
    MAX_BRANCHES = 50

    # RF-GH-025: a queued or running import that has not finished by
    # `expires_at` is shown as failed (Repository#current_import), so a job
    # lost with its Redis, or killed with its worker, does not stay
    # "Importing history…" forever. Generous: a normal import takes seconds.
    STALE_AFTER = 15.minutes

    # Enqueues the import and marks it as pending, so the UI does not show the
    # previous result in the meantime.
    def self.enqueue(repository)
      repository.set(last_import: pending("queued"))
      perform_async(repository.id.to_s)
    end

    def self.pending(status, from: Time.current)
      { "status" => status, "expires_at" => (from + STALE_AFTER).utc.iso8601 }
    end

    def perform(repository_id)
      repository = ::Repository.where(id: repository_id).first
      return unless repository

      team = ::Team.where(id: repository.team_id).first
      return unless team

      repository.set(last_import: self.class.pending("running"))
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
      # It waits for the quota to come back, so it only goes stale after that.
      repository&.set(last_import: self.class.pending("queued", from: e.reset_at))
      self.class.perform_at(e.reset_at, repository_id)
    rescue StandardError
      repository&.set(last_import: { "status" => "failed", "finished_at" => Time.current.utc.iso8601 })
      raise
    end

    private

    # RF-GH-023/026: walks the active branches (the ones with commits since
    # `since`) and creates one event per commit, with every branch it is on.
    # Non-default branches go first, so `branch` is the working branch and
    # attribution by branch works. Returns [commits, active branches], whether
    # already imported or not: that is what the user is shown.
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

    # A branch deleted between listing it and fetching its commits is skipped.
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

    # true if it creates the event; if it already existed it only adds the branches.
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
