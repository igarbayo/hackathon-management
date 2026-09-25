# RF-OBJ-001: each objective includes feature_count by status.
class ObjectiveSerializer
  def initialize(objective, feature_counts: nil)
    @objective = objective
    @feature_counts = feature_counts
  end

  def as_json
    {
      id: objective.id.to_s,
      key: objective.key,
      number: objective.number,
      title: objective.title,
      description: objective.description,
      priority: objective.priority,
      position: objective.position,
      archived: objective.archived?,
      feature_count: feature_counts || compute_feature_counts,
      created_at: objective.created_at.iso8601,
      updated_at: objective.updated_at.iso8601(3)
    }
  end

  private

  attr_reader :objective, :feature_counts

  def compute_feature_counts
    Feature.where(team_id: objective.team_id, objective_ids: objective.id)
           .group_by(&:status)
           .transform_values(&:size)
  end
end
