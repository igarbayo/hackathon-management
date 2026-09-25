# Layer 2 (RF-ATR-002): known branch. If the event's branch is in the
# branch_names of a single feature (and it is not the default branch), it is
# attributed. If there is more than one, it does not decide (it goes to layer
# 3).
module Attribution
  class ApplyBranch
    def self.call(event)
      new(event).call
    end

    def initialize(event)
      @event = event
    end

    def call
      return nil if event.branch.blank?
      return nil if default_branch?

      candidates = Feature.where(team_id: event.team_id, branch_names: event.branch).to_a
      return nil unless candidates.size == 1

      candidates.first
    end

    private

    attr_reader :event

    def default_branch?
      repository = event.repository
      repository.present? && repository.default_branch.present? && repository.default_branch == event.branch
    end
  end
end
