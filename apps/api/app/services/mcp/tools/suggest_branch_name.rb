module Mcp
  module Tools
    class SuggestBranchName
      def self.tool_name = "suggest_branch_name"
      def self.description = "Sugiere el nombre de rama para una feature, con el formato f-<numero>-<titulo-en-kebab>."
      def self.scope = nil
      def self.read_only? = true

      def self.input_schema
        { "type" => "object", "required" => [ "feature_key" ], "properties" => { "feature_key" => { "type" => "string" } }, "additionalProperties" => false }
      end

      def self.call(team:, membership:, resolved_token:, args:)
        feature = Mcp::FindFeature.call(team: team, key: args["feature_key"])
        kebab_title = feature.title.to_s.unicode_normalize(:nfd).gsub(/[̀-ͯ]/, "").downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")[0, 40]

        { branch_name: "#{feature.key.downcase}-#{kebab_title}" }
      end
    end
  end
end
