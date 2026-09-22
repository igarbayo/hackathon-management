class MilestoneSerializer
  def initialize(milestone)
    @milestone = milestone
  end

  def as_json
    {
      id: milestone.id.to_s,
      title: milestone.title,
      kind: milestone.kind,
      due_at: milestone.due_at&.iso8601,
      description: milestone.description
    }
  end

  private

  attr_reader :milestone
end
