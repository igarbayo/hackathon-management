module Mcp
  module FindObjective
    def self.call(team:, key:)
      objective = Objective.where(team_id: team.id, number: key.to_s.sub(/\AO-/i, "").to_i).first
      raise Mcp::ToolError, "#{key} no existe. Usa list_objectives." unless objective

      objective
    end
  end
end
