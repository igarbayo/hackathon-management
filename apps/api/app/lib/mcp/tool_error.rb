# Errores de dominio en una herramienta MCP: vuelven como resultado de
# herramienta con isError: true y un mensaje accionable, no como error de
# protocolo (12-acceso-programatico.md#reglas-del-servidor-mcp--rf-mcp-004-f5-aceptado).
module Mcp
  class ToolError < StandardError; end
end
