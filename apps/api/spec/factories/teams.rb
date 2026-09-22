FactoryBot.define do
  factory :team do
    sequence(:name) { |n| "Equipo #{n}" }

    hackathon { build(:hackathon) }

    trait :with_owner do
      after(:create) do |team|
        create(:membership, :owner, team: team)
      end
    end
  end

  factory :hackathon do
    name { "HackUSC 2026" }
    starts_at { 1.day.from_now }
    ends_at { 3.days.from_now }
    timezone { "Europe/Madrid" }
  end
end
