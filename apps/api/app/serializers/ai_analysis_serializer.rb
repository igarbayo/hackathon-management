class AiAnalysisSerializer
  def initialize(analysis, include_result: true)
    @analysis = analysis
    @include_result = include_result
  end

  def as_json
    base = {
      id: analysis.id.to_s,
      trigger: analysis.trigger,
      status: analysis.status,
      skip_reason: analysis.skip_reason,
      provider: analysis.provider,
      model: analysis.model,
      prompt_version: analysis.prompt_version,
      context_stats: analysis.context_stats,
      deterministic_alerts: analysis.deterministic_alerts,
      usage: analysis.usage,
      error: analysis.error,
      started_at: analysis.started_at&.iso8601,
      finished_at: analysis.finished_at&.iso8601,
      created_at: analysis.created_at.iso8601
    }

    base[:result] = analysis.result if include_result
    base
  end

  private

  attr_reader :analysis, :include_result
end
