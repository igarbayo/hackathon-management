module Mcp
  module Tools
    class MoveFeature
      def self.tool_name = "move_feature"
      def self.description = "Changes the status of a feature. It goes to the end of the target column."
      def self.scope = "features:write"
      def self.read_only? = false

      def self.input_schema
        {
          "type" => "object",
          "required" => %w[key status],
          "properties" => {
            "key" => { "type" => "string" },
            "status" => { "type" => "string", "enum" => Feature::STATUSES },
            "discarded_reason" => { "type" => "string" }
          },
          "additionalProperties" => false
        }
      end

      def self.call(team:, membership:, resolved_token:, args:)
        feature = Mcp::FindFeature.call(team: team, key: args["key"])

        feature.discarded_reason = args["discarded_reason"] if args["status"] == "discarded" && args["discarded_reason"].present?
        ::Features::Move.call(feature: feature, status: args["status"], via: resolved_token.via(channel: "mcp"))

        FeatureSerializer.new(feature, detail: true).as_json
      end
    end
  end
end
