# AI_PROVIDER (01-arquitectura.md): makes it possible to switch provider without
# touching the domain (ADR-0003). The caller resolves api_key (Ai::KeyOwner):
# each person uses their own, never a shared server key (RF-AI-021).
module Ai
  module ProviderFactory
    def self.build(api_key:)
      case ENV.fetch("AI_PROVIDER", "gemini")
      when "gemini" then Ai::Gemini.new(api_key: api_key)
      else raise "Unknown AI provider: #{ENV['AI_PROVIDER']}"
      end
    end
  end
end
