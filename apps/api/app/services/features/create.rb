module Features
  class Create
    def self.call(team:, created_by:, attrs:)
      feature = Feature.new(attrs)
      feature.team = team
      feature.created_by_id = created_by&.id
      feature.save!
      feature
    end
  end
end
