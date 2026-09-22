# Crea el AiAnalysis en estado queued (para poder devolver su id al
# instante, RF-AI-004) y encola el job que lo ejecuta.
module Analysis
  class Enqueue
    def self.call(team:, trigger:, requested_by: nil)
      analysis = AiAnalysis.create!(
        team_id: team.id, trigger: trigger, requested_by_id: requested_by&.id, status: "queued"
      )
      Analysis::RunJob.perform_async(analysis.id.to_s)
      analysis
    end
  end
end
