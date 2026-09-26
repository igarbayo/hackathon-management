module Mcp
  module Tools
    class AssignFeature
      def self.tool_name = "assign_feature"
      def self.description = "Adds or removes assignees of a feature. member is \"me\", an id or an exact display_name."
      def self.scope = "features:write"
      def self.read_only? = false

      def self.input_schema
        {
          "type" => "object",
          "required" => [ "key" ],
          "properties" => {
            "key" => { "type" => "string" },
            "add" => { "type" => "array", "items" => { "type" => "string" } },
            "remove" => { "type" => "array", "items" => { "type" => "string" } }
          },
          "additionalProperties" => false
        }
      end

      def self.call(team:, membership:, resolved_token:, args:)
        feature = Mcp::FindFeature.call(team: team, key: args["key"])

        add_ids = Array(args["add"]).map { |m| Mcp::ResolveMember.call(team: team, value: m, current_membership: membership).id.to_s }
        remove_ids = Array(args["remove"]).map { |m| Mcp::ResolveMember.call(team: team, value: m, current_membership: membership).id.to_s }

        new_ids = (feature.assignee_ids.map(&:to_s) + add_ids - remove_ids).uniq
        ::Features::Update.call(feature: feature, attrs: { "assignee_ids" => new_ids }, via: resolved_token.via(channel: "mcp"), actor: Tracking::Actor.for(membership: membership, resolved_token: resolved_token))

        FeatureSerializer.new(feature, detail: true).as_json
      end
    end
  end
end
