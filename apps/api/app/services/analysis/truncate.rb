# Si el contexto supera ~30.000 caracteres, se recorta en este orden
# (06-analisis-ia.md#construcción-del-contexto): títulos de actividad, rutas
# de ficheros, descripciones de features.
module Analysis
  class Truncate
    MAX_CHARS = 30_000

    def self.call(context)
      new(context).call
    end

    def initialize(context)
      @context = context
    end

    def call
      return context if within_budget?

      context["unattributed"]["titles"] = []
      context["features"].each { |f| f["activity"]&.dig("total")&.[]=("titles", []) }
      return context if within_budget?

      context["features"].each { |f| f["activity"]&.dig("total")&.[]=("files", []) }
      return context if within_budget?

      context["features"].each { |f| f["description"] = f["description"]&.first(100) }
      context
    end

    private

    attr_reader :context

    def within_budget?
      context.to_json.length <= MAX_CHARS
    end
  end
end
