# Alertas deterministas (06-analisis-ia.md#alertas-deterministas). Se
# calculan sin llamar a la IA, en cada petición a analyses/latest y también
# se guardan en el snapshot de AiAnalysis.
module Analysis
  class DeterministicAlerts
    def self.call(team)
      new(team).call
    end

    def initialize(team)
      @team = team
      @now = Time.current
    end

    def call
      [
        objective_without_features_alerts,
        feature_overdue_alerts,
        feature_unassigned_in_progress_alerts,
        feature_stale_alerts,
        milestone_soon_alerts,
        member_idle_alerts
      ].flatten
    end

    private

    attr_reader :team, :now

    def objective_without_features_alerts
      objectives = Objective.active.where(team_id: team.id).any_in(priority: %w[must should])
      hackathon = team.hackathon
      near_end = hackathon&.ends_at && (hackathon.ends_at - now) <= 6.hours

      objectives.filter_map do |objective|
        next if Feature.where(team_id: team.id, objective_ids: objective.id).where(:status.ne => "discarded").exists?

        if near_end
          alert("objective_without_features_near_end", "high", [objective.key])
        else
          alert("objective_without_features", objective.priority == "must" ? "high" : "medium", [objective.key])
        end
      end
    end

    def feature_overdue_alerts
      Feature.where(team_id: team.id, :deadline.lt => now).where(:status.nin => %w[done discarded]).map do |feature|
        alert("feature_overdue", "high", [feature.key])
      end
    end

    def feature_unassigned_in_progress_alerts
      Feature.where(team_id: team.id, status: "in_progress", assignee_ids: []).map do |feature|
        alert("feature_unassigned_in_progress", "medium", [feature.key])
      end
    end

    def feature_stale_alerts
      return [] unless during_hackathon?

      Feature.where(team_id: team.id, status: "in_progress").filter_map do |feature|
        last_event = ActivityEvent.where(team_id: team.id, "attribution.feature_id" => feature.id).order(occurred_at: :desc).first
        stale = last_event.nil? || last_event.occurred_at < now - 3.hours
        alert("feature_stale", "medium", [feature.key]) if stale
      end
    end

    def milestone_soon_alerts
      soon = Milestone.where(team_id: team.id, :due_at.gt => now, :due_at.lte => now + 1.hour)
      return [] if soon.empty?

      must_objective_ids = Objective.active.where(team_id: team.id, priority: "must").pluck(:id)
      return [] if must_objective_ids.empty?

      unfinished_keys = Feature.where(team_id: team.id, objective_ids: { "$in" => must_objective_ids })
                                .where(:status.nin => %w[done discarded])
                                .pluck(:number).map { |n| "F-#{n}" }
      return [] if unfinished_keys.empty?

      soon.map { |milestone| alert("milestone_soon", "high", unfinished_keys, milestone: milestone.title) }
    end

    def member_idle_alerts
      return [] unless during_hackathon?

      Membership.where(team_id: team.id).filter_map do |membership|
        last_event = ActivityEvent.where(team_id: team.id, "actor.user_id" => membership.user_id).order(occurred_at: :desc).first
        idle = last_event.nil? || last_event.occurred_at < now - 4.hours
        alert("member_idle", "low", [], member: membership.display_name, owners_only: true) if idle
      end
    end

    def during_hackathon?
      hackathon = team.hackathon
      return false unless hackathon&.starts_at && hackathon&.ends_at

      now.between?(hackathon.starts_at, hackathon.ends_at)
    end

    def alert(code, severity, related_keys, extra = {})
      { "code" => code, "severity" => severity, "related_keys" => related_keys }.merge(extra.stringify_keys)
    end
  end
end
