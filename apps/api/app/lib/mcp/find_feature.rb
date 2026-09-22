# Igual que FeatureLookup (el concern de los controladores REST) pero
# lanzando Mcp::ToolError en vez de ApiError::NotFound.
module Mcp
  module FindFeature
    def self.call(team:, key:)
      feature = if key.to_s.match?(/\AF-\d+\z/i)
        Feature.where(team_id: team.id, number: key.to_s.sub(/\AF-/i, "").to_i).first
      else
        Feature.where(team_id: team.id, id: key).first
      end
      raise Mcp::ToolError, "#{key} no existe. Usa list_features." unless feature

      feature
    end
  end
end
