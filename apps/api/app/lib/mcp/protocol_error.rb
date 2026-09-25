# JSON-RPC protocol error (unknown method, invalid params…), unlike
# Mcp::ToolError (a domain error inside a tool).
module Mcp
  class ProtocolError < StandardError
    attr_reader :code

    def initialize(code, message)
      @code = code
      super(message)
    end
  end
end
