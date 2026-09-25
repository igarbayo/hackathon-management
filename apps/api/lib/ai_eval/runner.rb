require_relative "dataset"

# RNF-AI-002 logic kept apart from the .rake so it can be tested without the
# task's exit killing the RSpec process.
module AiEval
  module Runner
    Score = Struct.new(:name, :accuracy, :actual, :error, keyword_init: true)

    def self.call(provider:, system_prompt:, schema:, dataset: AiEval::DATASET, out: $stdout)
      scores = dataset.map { |example| evaluate_case(example, provider: provider, system_prompt: system_prompt, schema: schema) }
      scores.each { |score| report_case(score, out) }

      overall = scores.sum(&:accuracy) / scores.size.to_f
      out.puts "\nAverage agreement: #{(overall * 100).round(1)}%"

      { scores: scores, overall: overall }
    end

    def self.evaluate_case(example, provider:, system_prompt:, schema:)
      result = provider.generate_json(system: system_prompt, prompt: example["context"].to_json, schema: schema)
      actual_by_key = result.data["coverage"].to_a.index_by { |row| row["objective_key"] }
      expected_rows = example["expected"]["coverage"]

      matches = expected_rows.count { |row| actual_by_key[row["objective_key"]]&.fetch("status", nil) == row["status"] }
      Score.new(name: example["name"], accuracy: matches / expected_rows.size.to_f, actual: result.data["coverage"])
    rescue Ai::Provider::GenerationError, Ai::Provider::InvalidOutputError => e
      Score.new(name: example["name"], accuracy: 0.0, error: e.message)
    end
    private_class_method :evaluate_case

    def self.report_case(score, out)
      status = score.accuracy == 1.0 ? "OK  " : "FAIL"
      out.puts "[#{status}] #{score.name} (#{(score.accuracy * 100).round}%)"
      return if score.accuracy == 1.0

      out.puts "       got: #{score.actual || score.error}"
    end
    private_class_method :report_case
  end
end
