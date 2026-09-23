# RNF-AI-002 (06-analisis-ia.md#evaluación--rnf-ai-002-f4-aceptado): se
# ejecuta contra el prompt/proveedor reales (hace falta GEMINI_API_KEY en el
# entorno de quien lo corre: es la única lectura de esa variable que queda en
# el repo, la app en producción ya no la usa, cada persona pone la suya en su
# perfil) antes de subir prompt_version. No corre en CI: llama a la IA de
# verdad y no es un test de comportamiento del código, es una evaluación de
# la calidad del prompt. La lógica vive en AiEval::Runner para poder
# probarla sin el exit.
namespace :ai do
  desc "Evalúa el prompt de cobertura actual contra el dataset de RNF-AI-002"
  task eval: :environment do
    require_relative "../ai_eval/runner"

    prompt_version = Analysis::RunJob::PROMPT_VERSION
    system_prompt = File.read(Rails.root.join("app/lib/ai/prompts", "#{prompt_version}.md"))
    schema = Ai::Schemas.load("coverage-analysis")

    puts "Evaluando prompt_version=#{prompt_version} contra #{AiEval::DATASET.size} casos…\n\n"
    provider = Ai::ProviderFactory.build(api_key: ENV.fetch("GEMINI_API_KEY"))
    result = AiEval::Runner.call(provider: provider, system_prompt: system_prompt, schema: schema)

    threshold = 0.8
    if result[:overall] < threshold
      warn "Por debajo del umbral (#{(threshold * 100).round}%). Revisa el prompt antes de subir prompt_version."
      exit 1
    end
  end
end
