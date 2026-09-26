# RF-FEAT-001/002: includes score and last_activity_at.
class FeatureSerializer
  # `viewer_id` (the person asking) adds `voted_by_me` to each argument
  # (RF-PC-011), so the web knows whether a click votes or removes the vote.
  # Without it (webhooks, MCP) the field is left out.
  def initialize(feature, detail: false, viewer_id: nil)
    @feature = feature
    @detail = detail
    @viewer_id = viewer_id
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

  attr_reader :feature, :detail, :viewer_id

  # RF-GH-026: branches with GitHub activity attributed to the feature, plus
  # the ones it has learned (branch_names). Only in the detail, to avoid one
  # query per kanban card.
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
    }.tap { |json| json[:voted_by_me] = argument.voter_ids.include?(viewer_id) if viewer_id }
  end

  def last_activity_at
    ActivityEvent.where(team_id: feature.team_id, "attribution.feature_id" => feature.id)
                 .order(occurred_at: :desc)
                 .first&.occurred_at
  end
end
