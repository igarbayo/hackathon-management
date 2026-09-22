# AI_PROVIDER (01-arquitectura.md): deja preparado el cambio de proveedor
# sin tocar el dominio (ADR-0003).
module Ai
  module ProviderFactory
    def self.build
      case ENV.fetch("AI_PROVIDER", "gemini")
      when "gemini" then Ai::Gemini.new
      else raise "Proveedor de IA desconocido: #{ENV['AI_PROVIDER']}"
      end
    end
  end
end
