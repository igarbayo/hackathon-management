# Like FeatureLookup (the REST controllers' concern) but raising Mcp::ToolError
# instead of ApiError::NotFound.
module Mcp
  module FindFeature
    def self.call(team:, key:)
      feature = if key.to_s.match?(/\AF-\d+\z/i)
        Feature.where(team_id: team.id, number: key.to_s.sub(/\AF-/i, "").to_i).first
      else
        Feature.where(team_id: team.id, id: key).first
      end
      raise Mcp::ToolError, "#{key} does not exist. Use list_features." unless feature

      feature
    end
  end
end
