require "rails_helper"

RSpec.describe Ai::Gemini do
  around do |example|
    original_model = ENV["GEMINI_MODEL"]
    ENV["GEMINI_MODEL"] = "gemini-test-model"
    example.run
    ENV["GEMINI_MODEL"] = original_model
  end

  let(:schema) { { type: "object", properties: { ok: { type: "boolean" } } } }

  it "sends responseSchema and responseMimeType, and passes the key in the query" do
    stub = stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-test-model:generateContent")
           .with(query: { key: "test-key" }) do |request|
      body = JSON.parse(request.body)
      expect(body["generationConfig"]["responseMimeType"]).to eq("application/json")
      expect(body["generationConfig"]["responseSchema"]).to eq(schema.deep_stringify_keys)
      true
    end.to_return(
      status: 200,
      body: {
        candidates: [ { content: { parts: [ { text: '{"ok":true}' } ] } } ],
        usageMetadata: { promptTokenCount: 120, candidatesTokenCount: 8 }
      }.to_json,
      headers: { "Content-Type" => "application/json" }
    )

    result = described_class.new(api_key: "test-key").generate_json(system: "you are an analyst", prompt: "hello", schema: schema)

    expect(stub).to have_been_requested
    expect(result.data).to eq({ "ok" => true })
    expect(result.usage).to eq(input_tokens: 120, output_tokens: 8)
    expect(result.model).to eq("gemini-test-model")
  end

  it "raises InvalidOutputError if the text is not valid JSON" do
    stub_request(:post, /generativelanguage\.googleapis\.com/).to_return(
      status: 200,
      body: { candidates: [ { content: { parts: [ { text: "not json" } ] } } ] }.to_json,
      headers: { "Content-Type" => "application/json" }
    )

    expect { described_class.new(api_key: "test-key").generate_json(system: "s", prompt: "p", schema: schema) }
      .to raise_error(Ai::Provider::InvalidOutputError)
  end

  it "raises GenerationError if Gemini returns an error" do
    stub_request(:post, /generativelanguage\.googleapis\.com/).to_return(status: 500, body: "boom")

    expect { described_class.new(api_key: "test-key").generate_json(system: "s", prompt: "p", schema: schema) }
      .to raise_error(Ai::Provider::GenerationError)
  end
end
