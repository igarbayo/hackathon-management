class ActivityEventSerializer
  def initialize(event)
    @event = event
  end

  def as_json
    {
      id: event.id.to_s,
      source: event.source,
      kind: event.kind,
      occurred_at: event.occurred_at.iso8601,
      actor: event.actor,
      repository_id: event.repository_id&.to_s,
      branch: event.branch,
      sha: event.sha,
      pr_number: event.pr_number,
      url: event.url,
      title: event.title,
      summary: event.summary,
      stats: event.stats,
      mentioned_feature_keys: event.mentioned_feature_keys,
      attribution: attribution_json,
      via: event.via
    }
  end

  private

  attr_reader :event

  def attribution_json
    attribution = event.attribution
    return nil unless attribution

    {
      feature_id: attribution.feature_id&.to_s,
      method: attribution.method,
      status: attribution.status,
      confidence: attribution.confidence,
      reason: attribution.reason,
      decided_by_id: attribution.decided_by_id&.to_s,
      decided_at: attribution.decided_at&.iso8601
    }
  end
end
