# Contexto para la capa 3 (05-atribucion.md#capa-3). Solo texto y metadatos,
# nunca diffs ni contenido de ficheros.
module Attribution
  class BuildSuggestionContext
    DESCRIPTION_LIMIT = 300
    MAX_FILE_PATHS = 20

    def self.call(team:, groups:)
      {
        "features" => features_section(team),
        "groups" => groups.map { |g| group_section(g) }
      }
    end

    def self.features_section(team)
      Feature.where(team_id: team.id).where(:status.ne => "discarded").map do |feature|
        {
          "key" => feature.key,
          "title" => feature.title,
          "description" => feature.description.to_s.first(DESCRIPTION_LIMIT),
          "branch_names" => feature.branch_names,
          "assignee_ids" => feature.assignee_ids.map(&:to_s)
        }
      end
    end
    private_class_method :features_section

    def self.group_section(group)
      event = group.events.first
      files = group.events.flat_map { |e| Array(e.files).filter_map { |f| f["path"] } }.uniq.first(MAX_FILE_PATHS)
      titles = group.events.filter_map(&:title).uniq

      {
        "group_id" => group.id,
        "actor" => event.actor["display"],
        "branch" => event.branch,
        "titles" => titles,
        "files" => files,
        "stats" => aggregate_stats(group.events),
        "rejected_feature_keys" => rejected_keys(group)
      }
    end
    private_class_method :group_section

    def self.aggregate_stats(events)
      {
        "additions" => events.sum { |e| e.stats["additions"].to_i },
        "deletions" => events.sum { |e| e.stats["deletions"].to_i },
        "event_count" => events.size
      }
    end
    private_class_method :aggregate_stats

    def self.rejected_keys(group)
      Feature.where(:id.in => group.rejected_feature_ids).map(&:key)
    end
    private_class_method :rejected_keys
  end
end
