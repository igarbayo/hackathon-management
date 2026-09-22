module Features
  class Create
    def self.call(team:, created_by:, attrs:)
      feature = Feature.new(attrs)
      feature.team = team
      feature.created_by_id = created_by&.id
      feature.save!
      ::Webhooks::Enqueue.call(team: team, event: "feature.created", data: FeatureSerializer.new(feature, detail: true).as_json)
      feature
    end
  end
end
