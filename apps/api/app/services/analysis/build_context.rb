# Construye el contexto que se envía a la IA (06-analisis-ia.md#construcción-del-contexto-analysisbuildcontext).
# Solo texto y metadatos. Nunca diffs, contenido de ficheros ni prompts.
module Analysis
  class BuildContext
    CHALLENGE_TEXT_LIMIT = 6_000
    OBJECTIVE_DESCRIPTION_LIMIT = 500
    FEATURE_DESCRIPTION_LIMIT = 400
    MAX_ACTIVITY_TITLES = 5
    MAX_FILE_PATHS = 15
    MAX_UNATTRIBUTED_TITLES = 10

    def self.call(team)
      new(team).call
    end

    def initialize(team)
      @team = team
      @now = Time.current
    end

    def call
      context = {
        "hackathon" => hackathon_section,
        "milestones" => milestones_section,
        "objectives" => objectives_section,
        "features" => features_section,
        "unattributed" => unattributed_section,
        "deterministic_alerts" => Analysis::DeterministicAlerts.call(team)
      }

      Truncate.call(context)
    end

    private

    attr_reader :team, :now

    def hackathon_section
      hackathon = team.hackathon
      {
        "name" => hackathon&.name,
        "now" => now.iso8601,
        "ends_at" => hackathon&.ends_at&.iso8601,
        "hours_remaining" => hours_between(now, hackathon&.ends_at),
        "challenge_text" => hackathon&.challenge_text.to_s.first(CHALLENGE_TEXT_LIMIT)
      }
    end

    def milestones_section
      Milestone.where(team_id: team.id).order(due_at: :asc).map do |milestone|
        {
          "title" => milestone.title,
          "kind" => milestone.kind,
          "due_at" => milestone.due_at.iso8601,
          "hours_remaining" => hours_between(now, milestone.due_at)
        }
      end
    end

    def objectives_section
      Objective.active.where(team_id: team.id).map do |objective|
        {
          "key" => objective.key,
          "title" => objective.title,
          "description" => objective.description.to_s.first(OBJECTIVE_DESCRIPTION_LIMIT),
          "priority" => objective.priority
        }
      end
    end

    def features_section
      Feature.where(team_id: team.id).map do |feature|
        if feature.status == "discarded"
          { "key" => feature.key, "title" => feature.title, "status" => "discarded" }
        else
          active_feature_json(feature)
        end
      end
    end

    def active_feature_json(feature)
      {
        "key" => feature.key,
        "title" => feature.title,
        "description" => feature.description.to_s.first(FEATURE_DESCRIPTION_LIMIT),
        "status" => feature.status,
        "objective_keys" => Objective.where(team_id: team.id, :id.in => feature.objective_ids).pluck(:number).map { |n| "O-#{n}" },
        "assignee_count" => feature.assignee_ids.size,
        "deadline" => feature.deadline&.iso8601,
        "score" => feature.score,
        "activity" => feature_activity(feature)
      }
    end

    def feature_activity(feature)
      events = ActivityEvent.where(team_id: team.id, "attribution.feature_id" => feature.id).order(occurred_at: :desc)
      recent_events = events.where(:occurred_at.gte => now - 6.hours)

      {
        "last_6h" => {
          "event_count" => recent_events.count,
          "people" => recent_events.to_a.filter_map { |e| e.actor["display"] }.uniq
        },
        "total" => {
          "event_count" => events.count,
          "last_activity_at" => events.first&.occurred_at&.iso8601,
          "titles" => events.limit(MAX_ACTIVITY_TITLES).to_a.filter_map(&:title),
          "files" => top_file_paths(events)
        }
      }
    end

    def top_file_paths(events)
      counts = Hash.new(0)
      events.limit(100).each do |event|
        Array(event.files).each { |f| counts[f["path"]] += 1 if f["path"] }
      end
      counts.sort_by { |_, count| -count }.first(MAX_FILE_PATHS).map(&:first)
    end

    def unattributed_section
      events = ActivityEvent.where(team_id: team.id, attribution: nil)
      {
        "count" => events.count,
        "titles" => events.order(occurred_at: :desc).limit(MAX_UNATTRIBUTED_TITLES).to_a.filter_map(&:title)
      }
    end

    def hours_between(from, to)
      return nil unless to

      ((to - from) / 3600.0).round(1)
    end
  end
end
