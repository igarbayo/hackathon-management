module Mcp
  module Tools
    class VoteArgument
      def self.tool_name = "vote_argument"
      def self.description = "Vota o quita el voto de un pro/contra."
      def self.scope = "arguments:write"
      def self.read_only? = false

      def self.input_schema
        {
          "type" => "object",
          "required" => %w[feature_key argument_id vote],
          "properties" => {
            "feature_key" => { "type" => "string" },
            "argument_id" => { "type" => "string" },
            "vote" => { "type" => "boolean" }
          },
          "additionalProperties" => false
        }
      end

      def self.call(team:, membership:, resolved_token:, args:)
        raise Mcp::ToolError, "vote_argument necesita un token de miembro o PAT de una persona." unless membership

        feature = Mcp::FindFeature.call(team: team, key: args["feature_key"])
        argument = feature.arguments.find(args["argument_id"])
        raise Mcp::ToolError, "Argumento no encontrado en #{feature.key}." unless argument

        if args["vote"]
          argument.add_to_set(voter_ids: membership.user_id)
        else
          argument.pull(voter_ids: membership.user_id)
        end

        Tracking::RecordApiChange.call(team: team, membership: membership, resolved_token: resolved_token, entity: "argument", key: "#{feature.key}/#{argument.id}", fields: %w[vote], channel: "mcp")

        { id: argument.id.to_s, votes: argument.reload.votes }
      end
    end
  end
end
