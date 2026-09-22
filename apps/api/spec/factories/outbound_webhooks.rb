FactoryBot.define do
  factory :outbound_webhook do
    team
    url { "https://example.com/hooks/hackboard" }
    events { [ "feature.status_changed" ] }
    secret { "s3cr3t-signing-key" }
    created_by_id { BSON::ObjectId.new }
  end
end
