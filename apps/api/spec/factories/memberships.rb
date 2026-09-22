FactoryBot.define do
  factory :membership do
    team
    user
    role { "member" }

    trait :owner do
      role { "owner" }
    end
  end
end
