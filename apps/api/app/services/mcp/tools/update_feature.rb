module Mcp
  module Tools
    class UpdateFeature
      def self.tool_name = "update_feature"
      def self.description = "Edits a feature. If expected_updated_at does not match the current value, it returns the conflict (like If-Match) instead of applying the change."
      def self.scope = "features:write"
      def self.read_only? = false

      def self.input_schema
        {
          "type" => "object",
          "required" => [ "key" ],
          "properties" => {
            "key" => { "type" => "string" },
            "title" => { "type" => "string" },
            "description" => { "type" => "string" },
            "deadline" => { "type" => "string", "format" => "date-time" },
            "objective_keys" => { "type" => "array", "items" => { "type" => "string" } },
            "expected_updated_at" => { "type" => "string", "format" => "date-time" }
          },
          "additionalProperties" => false
        }
      end

      def self.call(team:, membership:, resolved_token:, args:)
        feature = Mcp::FindFeature.call(team: team, key: args["key"])

        if args["expected_updated_at"].present? && feature.updated_at.iso8601(3) != Time.iso8601(args["expected_updated_at"]).iso8601(3)
          raise Mcp::ToolError, "Conflict: #{feature.key} has changed since then. Current state: #{FeatureSerializer.new(feature, detail: true).as_json.to_json}"
        end

        attrs = { "title" => args["title"], "description" => args["description"], "deadline" => args["deadline"] }.compact
        attrs["objective_ids"] = objective_ids_for(team, args["objective_keys"]) if args.key?("objective_keys")

        ::Features::Update.call(feature: feature, attrs: attrs, via: resolved_token.via(channel: "mcp"), actor: Tracking::Actor.for(membership: membership, resolved_token: resolved_token))
        Tracking::RecordApiChange.call(team: team, membership: membership, resolved_token: resolved_token, entity: "feature", key: feature.key, fields: attrs.keys, channel: "mcp")

        FeatureSerializer.new(feature, detail: true).as_json
      end

      def self.objective_ids_for(team, keys)
        Array(keys).map { |key| Mcp::FindObjective.call(team: team, key: key).id.to_s }
      end
      private_class_method :objective_ids_for
    end
  end
end
