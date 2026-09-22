# Error de protocolo JSON-RPC (método desconocido, parámetros inválidos…),
# a diferencia de Mcp::ToolError (error de dominio dentro de una herramienta).
module Mcp
  class ProtocolError < StandardError
    attr_reader :code

    def initialize(code, message)
      @code = code
      super(message)
    end
  end
end
