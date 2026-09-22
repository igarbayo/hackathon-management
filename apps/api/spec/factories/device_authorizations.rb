FactoryBot.define do
  factory :device_authorization do
    sequence(:device_code_digest) { |n| "device-digest-#{n}" }

    trait :approved do
      team
      membership
      status { "approved" }
      privacy_level { "metadata" }
    end
  end
end
