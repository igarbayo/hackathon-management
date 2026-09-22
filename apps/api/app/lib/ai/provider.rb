# Interfaz de proveedor de IA (ADR-0003, 06-analisis-ia.md#proveedor). La
# implementación por defecto es Ai::Gemini; cualquier otra tiene que exponer
# el mismo contrato para que el dominio no dependa de un proveedor concreto.
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
