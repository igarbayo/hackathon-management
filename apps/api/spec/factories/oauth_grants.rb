FactoryBot.define do
  factory :oauth_grant do
    team
    oauth_client
    user
    membership { association(:membership, team: team, user: user) }
    sequence(:code_digest) { |n| "code-digest-#{n}" }
    redirect_uri { "https://claude.ai/oauth/callback" }
    code_challenge { "challenge" }
    scopes { [ "read" ] }
    expires_at { 60.seconds.from_now }
  end
end
