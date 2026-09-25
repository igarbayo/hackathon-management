# Runs a coverage analysis already created in the queued status
# (06-analisis-ia.md#análisis-de-cobertura, Analysis::Enqueue). At most one
# running per team (Analysis::Lock). If the context has not changed since the
# last completed analysis, it does not call the AI (status: skipped).
module Analysis
  class RunJob
    include Sidekiq::Job
    sidekiq_options queue: "ai", retry: 3

    PROMPT_VERSION = "coverage_v2"

    def perform(analysis_id)
      analysis = AiAnalysis.where(id: analysis_id).first
      return unless analysis
      return unless analysis.status == "queued"

      team = Team.where(id: analysis.team_id).first
      return unless team
      return unless Analysis::Lock.acquire(analysis.team_id.to_s)

      begin
        run(analysis, team)
      ensure
        Analysis::Lock.release(analysis.team_id.to_s)
      end
    end

    private

    def run(analysis, team)
      context = Analysis::BuildContext.call(team)
      input_hash = Analysis::InputHash.call(context)
      last_completed = AiAnalysis.where(team_id: team.id, id: { "$ne" => analysis.id })
                                  .where(:status.in => %w[succeeded skipped])
                                  .order(created_at: :desc).first

      provider_name = ENV.fetch("AI_PROVIDER", "gemini")

      if last_completed && last_completed.input_hash == input_hash
        analysis.update!(status: "skipped", skip_reason: "no_changes", input_hash: input_hash, provider: provider_name, prompt_version: PROMPT_VERSION)
        return
      end

      api_key = resolve_api_key(analysis, team)
      if api_key.blank?
        analysis.update!(status: "skipped", skip_reason: "no_api_key", input_hash: input_hash, provider: provider_name, prompt_version: PROMPT_VERSION)
        return
      end

      analysis.update!(
        status: "running", provider: provider_name, prompt_version: PROMPT_VERSION,
        input_hash: input_hash, context_stats: context_stats(context), started_at: Time.current
      )

      generate(analysis, team, context, api_key)
    end

    # RF-AI-021: a manual analysis uses the key of whoever asked for it; a
    # scheduled one (no requested_by_id) uses the team owner's.
    def resolve_api_key(analysis, team)
      user = analysis.requested_by_id ? User.where(id: analysis.requested_by_id).first : Ai::KeyOwner.for(team)
      user&.gemini_api_key
    end

    def generate(analysis, team, context, api_key)
      system_prompt = File.read(Rails.root.join("app/lib/ai/prompts/#{PROMPT_VERSION}.md"))
      schema = Ai::Schemas.load("coverage-analysis")
      provider = Ai::ProviderFactory.build(api_key: api_key)

      result = with_one_retry do
        r = provider.generate_json(system: system_prompt, prompt: context.to_json, schema: schema)
        validate!(r.data, schema)
        r
      end

      final_result = Analysis::PostValidate.call(data: result.data, team: team)

      analysis.update!(
        status: "succeeded", model: result.model, result: final_result,
        deterministic_alerts: context["deterministic_alerts"], usage: result.usage.stringify_keys,
        finished_at: Time.current
      )
      ::Webhooks::Enqueue.call(team: team, event: "analysis.succeeded", data: AiAnalysisSerializer.new(analysis).as_json)
    rescue Ai::Provider::GenerationError, Ai::Provider::InvalidOutputError => e
      analysis.update!(status: "failed", error: e.message.to_s.first(500), finished_at: Time.current)
    end

    def with_one_retry
      yield
    rescue Ai::Provider::InvalidOutputError
      yield
    end

    def validate!(data, schema)
      schemer = JSONSchemer.schema(schema)
      raise Ai::Provider::InvalidOutputError, "the output does not match the schema" unless schemer.valid?(data)

      data
    end

    def context_stats(context)
      {
        "objectives" => context["objectives"].size,
        "features" => context["features"].size,
        "events" => context["features"].sum { |f| f.dig("activity", "total", "event_count").to_i },
        "chars" => context.to_json.length
      }
    end
  end
end
