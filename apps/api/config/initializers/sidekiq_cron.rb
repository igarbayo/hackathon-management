# Tareas periódicas (01-arquitectura.md#jobs-de-sidekiq). Solo se registran
# en el proceso de Sidekiq, no en cada boot de la web.
Sidekiq.configure_server do |config|
  config.on(:startup) do
    Sidekiq::Cron::Job.create(
      name: "analysis-schedule",
      cron: "* * * * *",
      class: "Analysis::ScheduleJob"
    )

    Sidekiq::Cron::Job.create(
      name: "attribution-ai-suggest",
      cron: "*/10 * * * *",
      class: "Attribution::AiSuggestJob"
    )

    Sidekiq::Cron::Job.create(
      name: "maintenance-retention",
      cron: "0 4 * * *",
      class: "Maintenance::RetentionJob"
    )

    Sidekiq::Cron::Job.create(
      name: "webhooks-milestone-due-soon",
      cron: "0 * * * *",
      class: "Webhooks::MilestoneDueSoonJob"
    )
  end
end
