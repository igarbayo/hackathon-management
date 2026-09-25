# Domain errors in an MCP tool: they come back as a tool result with isError: true and
# an actionable message, not as a protocol error
# (12-acceso-programatico.md#reglas-del-servidor-mcp--rf-mcp-004-f5-aceptado).
module Mcp
  class ToolError < StandardError; end
end
