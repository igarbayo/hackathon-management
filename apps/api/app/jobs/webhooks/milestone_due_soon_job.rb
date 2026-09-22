# Cada hora (12-acceso-programatico.md#webhooks-salientes): avisa 1h antes
# de due_at. due_soon_notified_at evita repetirlo en cada pasada.
module Webhooks
  class MilestoneDueSoonJob
    include Sidekiq::Job
    sidekiq_options queue: "default", retry: 3

    WINDOW = 1.hour

    def perform
      Milestone.where(due_soon_notified_at: nil, :due_at.gt => Time.current, :due_at.lte => WINDOW.from_now).each do |milestone|
        team = Team.where(id: milestone.team_id).first
        next unless team

        Webhooks::Enqueue.call(team: team, event: "milestone.due_soon", data: MilestoneSerializer.new(milestone).as_json)
        milestone.set(due_soon_notified_at: Time.current)
      end
    end
  end
end
