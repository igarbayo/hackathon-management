# POST /api/v1/ingest/claude_code (RF-CC-004). It validates and deduplicates
# right away (so it can return accepted/duplicates/rejected in the response) and
# leaves the actual creation of the ActivityEvents to Ingest::ProcessBatchJob.
module Ingest
  class ProcessBatch
    Result = Struct.new(:accepted, :duplicates, :rejected, keyword_init: true) do
      def as_json(*)
        { accepted: accepted, duplicates: duplicates, rejected: rejected }
      end
    end

    def self.call(team:, membership:, cli_version:, events:)
      new(team: team, membership: membership, cli_version: cli_version, events: events).call
    end

    def initialize(team:, membership:, cli_version:, events:)
      @team = team
      @membership = membership
      @cli_version = cli_version
      @events = events
    end

    def call
      link = membership.claude_code
      membership.update!(claude_code_attributes: { cli_version: cli_version, last_event_at: Time.current }) if link

      rejected = []
      candidates = []

      events.each do |event|
        errors = event_schema.validate(event).to_a
        if errors.any?
          rejected << { client_event_id: event["client_event_id"], reason: "invalid_schema" }
          next
        end

        if link.nil? || link.paused
          rejected << { client_event_id: event["client_event_id"], reason: "paused" }
          next
        end

        if link.privacy_level == "off"
          rejected << { client_event_id: event["client_event_id"], reason: "privacy_off" }
          next
        end

        unless repo_linked?(event["repo"]["remote"])
          rejected << { client_event_id: event["client_event_id"], reason: "repo_not_linked" }
          next
        end

        candidates << event
      end

      existing_keys = existing_dedupe_keys(candidates)
      duplicates = candidates.select { |e| existing_keys.include?("cc:#{e['client_event_id']}") }
      accepted = candidates - duplicates

      Ingest::ProcessBatchJob.perform_async(team.id.to_s, membership.id.to_s, accepted) if accepted.any?

      Result.new(accepted: accepted.size, duplicates: duplicates.size, rejected: rejected)
    end

    private

    attr_reader :team, :membership, :cli_version, :events

    def event_schema
      @event_schema ||= JSONSchemer.schema(Ai::Schemas.load("ingest-claude-code")["properties"]["events"]["items"])
    end

    def repo_linked?(remote)
      Repository.where(team_id: team.id, active: true, remote_urls: remote).exists?
    end

    def existing_dedupe_keys(candidates)
      keys = candidates.map { |e| "cc:#{e['client_event_id']}" }
      return [] if keys.empty?

      ActivityEvent.where(team_id: team.id).any_in(dedupe_key: keys).pluck(:dedupe_key)
    end
  end
end
