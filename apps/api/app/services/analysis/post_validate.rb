# Posvalidación de la salida de la IA (06-analisis-ia.md#esquema-de-salida).
# No se confía en que el modelo respete las claves ni la cobertura completa.
module Analysis
  class PostValidate
    def self.call(data:, team:)
      new(data: data, team: team).call
    end

    def initialize(data:, team:)
      @data = data
      @team = team
    end

    def call
      {
        "summary" => data["summary"].to_s,
        "coverage" => fixed_coverage,
        "orphan_features" => filtered_orphan_features,
        "gaps" => filtered_gaps,
        "risks" => filtered_risks
      }
    end

    private

    attr_reader :data, :team

    def objective_keys
      @objective_keys ||= Objective.active.where(team_id: team.id).map(&:key)
    end

    def feature_keys
      @feature_keys ||= Feature.where(team_id: team.id).map(&:key)
    end

    def non_discarded_feature_keys
      @non_discarded_feature_keys ||= Feature.where(team_id: team.id).where(:status.ne => "discarded").map(&:key)
    end

    def fixed_coverage
      by_key = Array(data["coverage"]).each_with_object({}) do |entry, acc|
        key = entry["objective_key"]
        next unless objective_keys.include?(key)
        next if acc.key?(key) # descarta duplicados, se queda con el primero

        acc[key] = {
          "objective_key" => key,
          "status" => %w[covered partial uncovered].include?(entry["status"]) ? entry["status"] : "uncovered",
          "feature_keys" => Array(entry["feature_keys"]) & feature_keys,
          "rationale" => entry["rationale"].to_s.first(300)
        }
      end

      objective_keys.map do |key|
        by_key[key] || { "objective_key" => key, "status" => "uncovered", "feature_keys" => [], "rationale" => "no evaluado" }
      end
    end

    def filtered_orphan_features
      Array(data["orphan_features"]).select { |o| non_discarded_feature_keys.include?(o["feature_key"]) }.map do |o|
        {
          "feature_key" => o["feature_key"],
          "rationale" => o["rationale"].to_s.first(300),
          "recommendation" => %w[discard link_objective keep].include?(o["recommendation"]) ? o["recommendation"] : "keep",
          "suggested_objective_key" => objective_keys.include?(o["suggested_objective_key"]) ? o["suggested_objective_key"] : nil
        }
      end
    end

    def filtered_gaps
      Array(data["gaps"]).map do |g|
        {
          "objective_key" => objective_keys.include?(g["objective_key"]) ? g["objective_key"] : nil,
          "description" => g["description"].to_s.first(300),
          "suggested_feature_title" => g["suggested_feature_title"].to_s.first(120)
        }
      end
    end

    def filtered_risks
      Array(data["risks"]).map do |r|
        {
          "severity" => %w[low medium high].include?(r["severity"]) ? r["severity"] : "low",
          "kind" => %w[deadline scope unassigned inactivity quality other].include?(r["kind"]) ? r["kind"] : "other",
          "description" => r["description"].to_s.first(300),
          "related_keys" => (Array(r["related_keys"]) & (objective_keys + feature_keys))
        }
      end
    end
  end
end
