FactoryBot.define do
  factory :access_token do
    team
    membership { association(:membership, team: team) }
    kind { "pat" }
    sequence(:name) { |n| "Token #{n}" }
    sequence(:token_digest) { |n| "digest-#{n}" }
    token_prefix { "hb_pat_abcd" }
    scopes { [ "read" ] }
    expires_at { 30.days.from_now }

    trait :integration do
      kind { "integration" }
      membership { nil }
      created_by_id { BSON::ObjectId.new }
    end

    trait :oauth do
      kind { "oauth" }
      oauth_client
      refresh_family_id { SecureRandom.uuid }
    end
  end
end
