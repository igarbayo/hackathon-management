FactoryBot.define do
  factory :session do
    user
    sequence(:token_digest) { |n| "session-digest-#{n}" }
    expires_at { 30.days.from_now }
    user_agent { "RSpec" }
    ip { "127.0.0.1" }
  end
end
