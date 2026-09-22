module Mcp
  module Tools
    class AddArgument
      def self.tool_name = "add_argument"
      def self.description = "Añade un pro o un contra a una feature, con el miembro que llama como autor."
      def self.scope = "arguments:write"
      def self.read_only? = false

      def self.input_schema
        {
          "type" => "object",
          "required" => %w[feature_key kind text],
          "properties" => {
            "feature_key" => { "type" => "string" },
            "kind" => { "type" => "string", "enum" => %w[pro con] },
            "text" => { "type" => "string", "maxLength" => 280 }
          },
          "additionalProperties" => false
        }
      end

      def self.call(team:, membership:, resolved_token:, args:)
        raise Mcp::ToolError, "add_argument necesita un token de miembro o PAT de una persona." unless membership

        feature = Mcp::FindFeature.call(team: team, key: args["feature_key"])
        argument = feature.arguments.create!(kind: args["kind"], text: args["text"], author_id: membership.user_id)
        Tracking::RecordApiChange.call(team: team, membership: membership, resolved_token: resolved_token, entity: "argument", key: "#{feature.key}/#{argument.id}", fields: %w[kind text], channel: "mcp")

        { id: argument.id.to_s, kind: argument.kind, text: argument.text, votes: argument.votes }
      end
    end
  end
end
