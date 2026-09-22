# Agrupa eventos candidatos a la capa 3 por (actor, rama, sesión), para
# mandar pocas peticiones a la IA con sentido (05-atribucion.md#capa-3).
module Attribution
  class GroupEvents
    Group = Struct.new(:id, :events, keyword_init: true) do
      def rejected_feature_ids
        events.flat_map { |e| e.attribution&.rejected_feature_ids || [] }.uniq
      end

      def never_attempted?
        events.any? { |e| e.ai_suggestion_attempted_at.nil? }
      end
    end

    def self.call(events)
      events.group_by { |e| [ e.actor["user_id"], e.branch, e.session_ref ] }
            .map { |key, group_events| Group.new(id: Digest::SHA256.hexdigest(key.join("|"))[0, 12], events: group_events) }
    end
  end
end
