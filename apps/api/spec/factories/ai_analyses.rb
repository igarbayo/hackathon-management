FactoryBot.define do
  factory :ai_analysis do
    team
    trigger { "manual" }
    status { "queued" }
    provider { "gemini" }
  end
end
