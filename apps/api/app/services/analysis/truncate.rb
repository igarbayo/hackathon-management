# If the context goes over ~30,000 characters, it is cut in this order
# (06-analisis-ia.md#construcción-del-contexto): activity titles, file paths,
# feature descriptions.
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
