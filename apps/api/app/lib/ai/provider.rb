# AI provider interface (ADR-0003, 06-analisis-ia.md#proveedor). The default
# implementation is Ai::Gemini; any other must expose the same contract so the
# domain does not depend on a specific provider.
module Ai
  class Provider
    class GenerationError < StandardError; end
    class InvalidOutputError < StandardError; end

    Result = Struct.new(:data, :usage, :model, keyword_init: true)

    # @return [Ai::Provider::Result]
    def generate_json(system:, prompt:, schema:, temperature: 0.2, max_output_tokens: nil)
      raise NotImplementedError
    end
  end
end
