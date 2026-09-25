# Creates the AiAnalysis in the queued status (so its id can be returned right
# away, RF-AI-004) and queues the job that runs it.
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
