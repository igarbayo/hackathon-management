# Catálogo de herramientas del servidor MCP
# (12-acceso-programatico.md#servidor-mcp). tools/list solo devuelve las
# que el token puede usar (RF-MCP-004).
module Mcp
  module Registry
    TOOLS = [
      Mcp::Tools::Whoami,
      Mcp::Tools::GetTeamStatus,
      Mcp::Tools::ListFeatures,
      Mcp::Tools::GetFeature,
      Mcp::Tools::ListObjectives,
      Mcp::Tools::GetTimeline,
      Mcp::Tools::ListActivity,
      Mcp::Tools::GetLatestAnalysis,
      Mcp::Tools::SuggestBranchName,
      Mcp::Tools::ReportProgress,
      Mcp::Tools::CreateFeature,
      Mcp::Tools::UpdateFeature,
      Mcp::Tools::MoveFeature,
      Mcp::Tools::AssignFeature,
      Mcp::Tools::AddArgument,
      Mcp::Tools::VoteArgument,
      Mcp::Tools::CreateObjective,
      Mcp::Tools::UpdateObjective,
      Mcp::Tools::CreateMilestone,
      Mcp::Tools::UpdateMilestone,
      Mcp::Tools::SetAttribution,
      Mcp::Tools::RunAnalysis
    ].freeze

    def self.all
      TOOLS
    end

    def self.for_scopes(scopes)
      TOOLS.select { |tool| tool.scope.nil? || scopes.include?(tool.scope) }
    end

    def self.find(name)
      TOOLS.find { |tool| tool.tool_name == name }
    end
  end
end
