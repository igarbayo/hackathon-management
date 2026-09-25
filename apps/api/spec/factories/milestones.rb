FactoryBot.define do
  factory :milestone do
    team
    title { "Final demo" }
    kind { "demo" }
    due_at { 2.days.from_now }
  end
end
