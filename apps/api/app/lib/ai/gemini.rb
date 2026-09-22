# Implementación por defecto de Ai::Provider (ADR-0003). El modelo se
# configura con GEMINI_MODEL: qué modelo concreto usar por defecto queda
# [ABIERTO] en 06-analisis-ia.md, así que no se hardcodea ninguno aquí.
module Ai
  class Gemini < Provider
    API_BASE = "https://generativelanguage.googleapis.com/v1beta/"
    TIMEOUT = 60

    def generate_json(system:, prompt:, schema:, temperature: 0.2, max_output_tokens: nil)
      body = request_body(system: system, prompt: prompt, schema: schema, temperature: temperature, max_output_tokens: max_output_tokens)

      response = connection.post("models/#{model}:generateContent") do |req|
        req.params["key"] = api_key
        req.body = body
      end

      raise Provider::GenerationError, "Gemini respondió #{response.status}: #{response.body}" unless response.success?

      parse_response(response.body)
    end

    private

    def request_body(system:, prompt:, schema:, temperature:, max_output_tokens:)
      generation_config = {
        responseMimeType: "application/json",
        responseSchema: schema,
        temperature: temperature
      }
      generation_config[:maxOutputTokens] = max_output_tokens if max_output_tokens

      {
        systemInstruction: { parts: [ { text: system } ] },
        contents: [ { role: "user", parts: [ { text: prompt } ] } ],
        generationConfig: generation_config
      }
    end

    def parse_response(body)
      text = body.dig("candidates", 0, "content", "parts", 0, "text")
      raise Provider::GenerationError, "Gemini no devolvió texto" if text.blank?

      data = JSON.parse(text)
      usage = {
        input_tokens: body.dig("usageMetadata", "promptTokenCount"),
        output_tokens: body.dig("usageMetadata", "candidatesTokenCount")
      }

      Provider::Result.new(data: data, usage: usage, model: model)
    rescue JSON::ParserError => e
      raise Provider::InvalidOutputError, "Gemini no devolvió JSON válido: #{e.message}"
    end

    def model
      ENV.fetch("GEMINI_MODEL")
    end

    def api_key
      ENV.fetch("GEMINI_API_KEY")
    end

    def connection
      Faraday.new(url: API_BASE) do |f|
        f.request :json
        f.response :json, content_type: /\bjson\b/
        f.options.timeout = TIMEOUT
        f.adapter Faraday.default_adapter
      end
    end
  end
end
