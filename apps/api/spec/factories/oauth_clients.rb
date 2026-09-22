FactoryBot.define do
  factory :oauth_client do
    sequence(:client_id) { |n| "client-#{n}" }
    registration { "dynamic" }
    name { "claude.ai" }
    redirect_uris { ["https://claude.ai/oauth/callback"] }
  end
end
