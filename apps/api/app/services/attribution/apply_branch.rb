# Capa 2 (RF-ATR-002): rama conocida. Si la rama del evento está en
# branch_names de una única feature (y no es la rama por defecto), se
# atribuye. Si hay más de una, no decide (pasa a la capa 3).
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
