FactoryBot.define do
  factory :activity_event do
    team
    source { "system" }
    kind { "member_joined" }
    sequence(:dedupe_key) { |n| "system:member_joined:#{n}" }
    occurred_at { Time.current }

    trait :github_commit do
      source { "github" }
      kind { "commit" }
      sha { SecureRandom.hex(20) }
    end

    trait :claude_turn do
      source { "claude_code" }
      kind { "cc_turn" }
    end
  end
end
