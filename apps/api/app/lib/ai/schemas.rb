# Loads the JSON Schemas from packages/shared-schemas/schemas, the single
# contract definition shared with the CLI (01-arquitectura.md).
module Ai
  module Schemas
    SCHEMAS_DIR = Rails.root.join("..", "..", "packages", "shared-schemas", "schemas")

    def self.load(name)
      path = SCHEMAS_DIR.join("#{name}.schema.json")
      raise "There is no schema #{name.inspect} in #{SCHEMAS_DIR}" unless File.exist?(path)

      JSON.parse(File.read(path))
    end
  end
end
