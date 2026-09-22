FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    name { "Ada Lovelace" }
    password { "supersecret123" }
  end
end
