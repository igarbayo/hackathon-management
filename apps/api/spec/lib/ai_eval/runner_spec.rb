require "rails_helper"
require Rails.root.join("lib/ai_eval/runner")

RSpec.describe AiEval::Runner do
  let(:schema) { Ai::Schemas.load("coverage-analysis") }
  let(:out) { StringIO.new }

  it "puntúa 100% cuando el proveedor devuelve exactamente lo esperado" do
    provider = instance_double(Ai::Gemini)
    dataset = AiEval::DATASET.first(2)
    dataset.each do |example|
      allow(provider).to receive(:generate_json)
        .with(system: "prompt", prompt: example["context"].to_json, schema: schema)
        .and_return(Ai::Provider::Result.new(data: example["expected"], usage: {}, model: "test"))
    end

    result = described_class.call(provider: provider, system_prompt: "prompt", schema: schema, dataset: dataset, out: out)

    expect(result[:overall]).to eq(1.0)
    expect(out.string).to include("[OK  ]")
  end

  it "puntúa por debajo de 1.0 si el estado no coincide, y lo reporta como FAIL" do
    provider = instance_double(Ai::Gemini)
    example = AiEval::DATASET.find { |e| e["expected"]["coverage"].none? { |r| r["status"] == "covered" } }
    wrong_output = { "coverage" => example["expected"]["coverage"].map { |r| r.merge("status" => "covered") } }
    allow(provider).to receive(:generate_json).and_return(Ai::Provider::Result.new(data: wrong_output, usage: {}, model: "test"))

    result = described_class.call(provider: provider, system_prompt: "prompt", schema: schema, dataset: [ example ], out: out)

    expect(result[:overall]).to be < 1.0
    expect(out.string).to include("[FAIL]")
  end

  it "puntúa 0 si el proveedor falla, sin reventar la evaluación completa" do
    provider = instance_double(Ai::Gemini)
    allow(provider).to receive(:generate_json).and_raise(Ai::Provider::GenerationError, "timeout")

    result = described_class.call(provider: provider, system_prompt: "prompt", schema: schema, dataset: AiEval::DATASET.first(1), out: out)

    expect(result[:overall]).to eq(0.0)
    expect(out.string).to include("timeout")
  end

  it "el dataset tiene entre 5 y 10 casos (RNF-AI-002)" do
    expect(AiEval::DATASET.size).to be_between(5, 10)
  end
end
