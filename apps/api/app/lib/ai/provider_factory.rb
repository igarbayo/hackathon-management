# AI_PROVIDER (01-arquitectura.md): deja preparado el cambio de proveedor
# sin tocar el dominio (ADR-0003). api_key la resuelve la llamada (Ai::KeyOwner):
# cada persona usa la suya, nunca una compartida del servidor (RF-AI-021).
module Ai
  module ProviderFactory
    def self.build(api_key:)
      case ENV.fetch("AI_PROVIDER", "gemini")
      when "gemini" then Ai::Gemini.new(api_key: api_key)
      else raise "Proveedor de IA desconocido: #{ENV['AI_PROVIDER']}"
      end
    end
  end
end
