module Mcp
  module Tools
    class CreateFeature
      def self.tool_name = "create_feature"
      def self.description = "Crea una feature en estado idea y devuelve su clave."
      def self.scope = "features:write"
      def self.read_only? = false

      def self.input_schema
        {
          "type" => "object",
          "required" => [ "title" ],
          "properties" => {
            "title" => { "type" => "string" },
            "description" => { "type" => "string" },
            "objective_keys" => { "type" => "array", "items" => { "type" => "string" } },
            "deadline" => { "type" => "string", "format" => "date-time" },
            "assign_to_me" => { "type" => "boolean" },
            "idempotency_key" => { "type" => "string", "maxLength" => 64 }
          },
          "additionalProperties" => false
        }
      end

      def self.call(team:, membership:, resolved_token:, args:)
        cached = Mcp::Idempotency.fetch(resolved_token, "create_feature", args["idempotency_key"])
        return cached if cached

        attrs = {
          "title" => args["title"],
          "description" => args["description"],
          "objective_ids" => objective_ids_for(team, args["objective_keys"]),
          "deadline" => args["deadline"]
        }.compact

        if args["assign_to_me"]
          raise Mcp::ToolError, "assign_to_me no está disponible para un token de integración." unless membership

          attrs["assignee_ids"] = [ membership.id.to_s ]
        end

        feature = ::Features::Create.call(team: team, created_by: membership&.user, attrs: attrs)
        Tracking::RecordApiChange.call(team: team, membership: membership, resolved_token: resolved_token, entity: "feature", key: feature.key, fields: attrs.keys, channel: "mcp")

        result = { key: feature.key, id: feature.id.to_s }
        Mcp::Idempotency.store(resolved_token, "create_feature", args["idempotency_key"], result)
        result
      end

      def self.objective_ids_for(team, keys)
        return nil if keys.blank?

        keys.map { |key| Mcp::FindObjective.call(team: team, key: key).id.to_s }
      end
      private_class_method :objective_ids_for
    end
  end
end
