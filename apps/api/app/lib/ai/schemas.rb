# Carga los JSON Schema de packages/shared-schemas/schemas, la única
# definición por contrato compartida con el CLI (01-arquitectura.md).
module Ai
  module Schemas
    SCHEMAS_DIR = Rails.root.join("..", "..", "packages", "shared-schemas", "schemas")

    def self.load(name)
      path = SCHEMAS_DIR.join("#{name}.schema.json")
      raise "No existe el schema #{name.inspect} en #{SCHEMAS_DIR}" unless File.exist?(path)

      JSON.parse(File.read(path))
    end
  end
end
