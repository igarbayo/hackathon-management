# JSON-RPC 2.0 sobre Streamable HTTP (12-acceso-programatico.md#servidor-mcp).
# Una sola respuesta JSON por petición: no hace falta SSE para el catálogo
# de herramientas de Hackboard (ninguna es de larga duración).
module Mcp
  class Dispatch
    PROTOCOL_VERSION = "2025-06-18"
    SERVER_NAME = "hackboard"

    def self.call(team:, membership:, resolved_token:, message:, session_id:)
      new(team: team, membership: membership, resolved_token: resolved_token, message: message, session_id: session_id).call
    end

    def initialize(team:, membership:, resolved_token:, message:, session_id:)
      @team = team
      @membership = membership
      @resolved_token = resolved_token
      @message = message
      @session_id = session_id
    end

    def call
      return error_response(-32600, "petición JSON-RPC inválida") unless message.is_a?(Hash) && message["jsonrpc"] == "2.0"

      result = route
      return Mcp::Notification.new if result.is_a?(Mcp::Notification)

      { "jsonrpc" => "2.0", "id" => message["id"], "result" => result }
    rescue Mcp::ProtocolError => e
      error_response(e.code, e.message)
    end

    private

    attr_reader :team, :membership, :resolved_token, :message, :session_id

    def route
      case message["method"]
      when "initialize" then handle_initialize
      when "notifications/initialized" then Mcp::Notification.new
      when "tools/list" then handle_tools_list
      when "tools/call" then handle_tools_call
      else
        raise Mcp::ProtocolError.new(-32601, "método desconocido: #{message['method']}")
      end
    end

    def handle_initialize
      client_name = message.dig("params", "clientInfo", "name")
      new_session_id = Mcp::SessionStore.create(client_name)

      {
        "protocolVersion" => PROTOCOL_VERSION,
        "capabilities" => { "tools" => {} },
        "serverInfo" => { "name" => SERVER_NAME, "version" => "1.0" },
        "_meta" => { "sessionId" => new_session_id }
      }
    end

    def handle_tools_list
      { "tools" => Mcp::Registry.for_scopes(resolved_token.scopes).map { |tool| tool_definition(tool) } }
    end

    def tool_definition(tool)
      {
        "name" => tool.tool_name,
        "description" => tool.description,
        "inputSchema" => tool.input_schema,
        "annotations" => { "readOnlyHint" => tool.read_only?, "destructiveHint" => false }
      }
    end

    def handle_tools_call
      resolved_token.client_name = Mcp::SessionStore.client_name(session_id)
      name = message.dig("params", "name")
      tool = Mcp::Registry.find(name)
      raise Mcp::ProtocolError.new(-32602, "herramienta desconocida: #{name}") unless tool
      raise Mcp::ProtocolError.new(-32000, "al token le falta el scope #{tool.scope}") unless tool.scope.nil? || resolved_token.scopes.include?(tool.scope)

      args = message.dig("params", "arguments") || {}

      begin
        data = tool.call(team: team, membership: membership, resolved_token: resolved_token, args: args)
        { "content" => [ { "type" => "text", "text" => data.to_json } ] }
      rescue Mcp::ToolError => e
        { "content" => [ { "type" => "text", "text" => e.message } ], "isError" => true }
      end
    end

    def error_response(code, message_text)
      { "jsonrpc" => "2.0", "id" => message.is_a?(Hash) ? message["id"] : nil, "error" => { "code" => code, "message" => message_text } }
    end
  end
end
