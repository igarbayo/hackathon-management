# RF-FEAT-001/002: incluye score y last_activity_at.
class FeatureSerializer
  def initialize(feature, detail: false)
    @feature = feature
    @detail = detail
  end

  def as_json
    base = {
      id: feature.id.to_s,
      key: feature.key,
      number: feature.number,
      title: feature.title,
      description: feature.description,
      status: feature.status,
      position: feature.position,
      objective_ids: feature.objective_ids.map(&:to_s),
      assignee_ids: feature.assignee_ids.map(&:to_s),
      deadline: feature.deadline&.iso8601,
      branch_names: feature.branch_names,
      score: feature.score,
      last_activity_at: last_activity_at&.iso8601,
      status_changed_at: feature.status_changed_at&.iso8601,
      updated_at: feature.updated_at.iso8601(3),
      created_at: feature.created_at.iso8601
    }

    if detail
      base[:arguments] = feature.arguments.map { |a| argument_json(a) }
      base[:activity_branches] = activity_branches
    end

    base
  end

  private

  attr_reader :feature, :detail

  # RF-GH-026: ramas en las que hay actividad de GitHub atribuida a la
  # feature, más las que ha aprendido (branch_names). Solo en el detalle,
  # para no hacer una consulta por tarjeta del kanban.
  def activity_branches
    events = ActivityEvent.where(team_id: feature.team_id, source: "github", "attribution.feature_id" => feature.id)
    (feature.branch_names + events.distinct(:branches) + events.distinct(:branch)).compact.uniq.sort
  end

  def argument_json(argument)
    {
      id: argument.id.to_s,
      kind: argument.kind,
      text: argument.text,
      author_id: argument.author_id&.to_s,
      votes: argument.votes,
      created_at: argument.created_at.iso8601
    }
  end

  def last_activity_at
    ActivityEvent.where(team_id: feature.team_id, "attribution.feature_id" => feature.id)
                 .order(occurred_at: :desc)
                 .first&.occurred_at
  end
end
