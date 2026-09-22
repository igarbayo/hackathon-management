FactoryBot.define do
  factory :milestone do
    team
    title { "Demo final" }
    kind { "demo" }
    due_at { 2.days.from_now }
  end
end
