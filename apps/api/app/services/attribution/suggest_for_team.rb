# Orquesta la capa 3 para un equipo (05-atribucion.md#capa-3): agrupa,
# aplica la heurística sin IA y, para lo que quede, hace una llamada por
# lotes a la IA. Máx. 60 eventos por lote.
module Attribution
  class SuggestForTeam
    MAX_EVENTS_PER_BATCH = 60
    PROMPT_VERSION = "attribution_v1"
    MIN_CONFIDENCE = 0.5

    def self.call(team)
      new(team).call
    end

    def initialize(team)
      @team = team
    end

    def call
      return unless team.settings["ai_attribution_enabled"]

      groups = eligible_groups
      return if groups.empty?

      remaining = []
      groups.each do |group|
        suggestion = Attribution::Heuristic.call(team: team, group: group)
        if suggestion
          apply(group, feature: suggestion[:feature], confidence: suggestion[:confidence], reason: suggestion[:reason])
        else
          remaining << group
        end
      end

      ask_ai(remaining) if remaining.any?
    end

    private

    attr_reader :team

    def eligible_groups
      events = ActivityEvent.where(team_id: team.id, :occurred_at.gte => 24.hours.ago)
                             .any_in(kind: ActivityEvent::ATTRIBUTABLE_KINDS)
                             .any_of({ attribution: nil }, { "attribution.status" => "rejected" })
                             .to_a

      Attribution::GroupEvents.call(events)
                               .select(&:never_attempted?)
                               .sort_by { |g| g.events.map(&:occurred_at).min }
                               .each_with_object([]) do |group, acc|
        break acc if acc.sum { |g| g.events.size } + group.events.size > MAX_EVENTS_PER_BATCH && acc.any?

        acc << group
      end
    end

    def ask_ai(groups)
      # RF-AI-021: es un job de fondo sin actor, así que usa la clave del
      # owner del equipo. Sin ella, no se llama a la IA (sin fallback).
      api_key = Ai::KeyOwner.for(team)&.gemini_api_key
      return groups.each { |g| mark_attempted(g) } if api_key.blank?

      context = Attribution::BuildSuggestionContext.call(team: team, groups: groups)
      system_prompt = File.read(Rails.root.join("app/lib/ai/prompts/#{PROMPT_VERSION}.md"))
      schema = Ai::Schemas.load("attribution-suggestion")

      response = Ai::ProviderFactory.build(api_key: api_key).generate_json(system: system_prompt, prompt: context.to_json, schema: schema)
      by_group = groups.index_by(&:id)

      Array(response.data["assignments"]).each do |assignment|
        group = by_group[assignment["group_id"]]
        next unless group

        apply_assignment(group, assignment)
      end
    rescue Ai::Provider::GenerationError, Ai::Provider::InvalidOutputError
      groups.each { |g| mark_attempted(g) }
    end

    def apply_assignment(group, assignment)
      feature = valid_feature(group, assignment["feature_key"])
      confidence = assignment["confidence"].to_f

      if feature && confidence >= MIN_CONFIDENCE
        apply(group, feature: feature, confidence: confidence, reason: assignment["reason"].to_s.first(280))
      else
        mark_attempted(group)
      end
    end

    def valid_feature(group, feature_key)
      return nil if feature_key.blank?

      feature = Feature.where({ team_id: team.id }.merge(key_number(feature_key))).where(:status.ne => "discarded").first
      return nil unless feature
      return nil if group.rejected_feature_ids.include?(feature.id)

      feature
    end

    def key_number(feature_key)
      match = feature_key.to_s.match(/\AF-(\d+)\z/)
      match ? { number: match[1].to_i } : { number: -1 }
    end

    def apply(group, feature:, confidence:, reason:)
      group.events.each do |event|
        rejected = event.attribution&.rejected_feature_ids || []
        event.build_attribution(
          feature_id: feature.id, method: "ai", status: "suggested",
          confidence: confidence, reason: reason, rejected_feature_ids: rejected
        )
        event.save!
      end
    end

    def mark_attempted(group)
      group.events.each { |e| e.set(ai_suggestion_attempted_at: Time.current) }
    end
  end
end
