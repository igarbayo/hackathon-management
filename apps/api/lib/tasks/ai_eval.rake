# RNF-AI-002 (06-analisis-ia.md#evaluación--rnf-ai-002-f4-aceptado): it runs
# against the real prompt/provider (whoever runs it needs GEMINI_API_KEY in
# their environment: it is the only read of that variable left in the repo; the
# production app no longer uses it, each person sets their own in their profile)
# before bumping prompt_version. It does not run in CI: it really calls the AI
# and it is not a test of the code's behavior, it is an evaluation of the
# prompt's quality. The logic lives in AiEval::Runner so it can be tested
# without the exit.
namespace :ai do
  desc "Evaluates the current coverage prompt against the RNF-AI-002 dataset"
  task eval: :environment do
    require_relative "../ai_eval/runner"

    prompt_version = Analysis::RunJob::PROMPT_VERSION
    system_prompt = File.read(Rails.root.join("app/lib/ai/prompts", "#{prompt_version}.md"))
    schema = Ai::Schemas.load("coverage-analysis")

    puts "Evaluating prompt_version=#{prompt_version} against #{AiEval::DATASET.size} cases…\n\n"
    provider = Ai::ProviderFactory.build(api_key: ENV.fetch("GEMINI_API_KEY"))
    result = AiEval::Runner.call(provider: provider, system_prompt: system_prompt, schema: schema)

    threshold = 0.8
    if result[:overall] < threshold
      warn "Below the threshold (#{(threshold * 100).round}%). Review the prompt before bumping prompt_version."
      exit 1
    end
  end
end
