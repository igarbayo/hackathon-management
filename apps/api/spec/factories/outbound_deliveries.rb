FactoryBot.define do
  factory :outbound_delivery do
    team
    outbound_webhook { association(:outbound_webhook, team: team) }
    event { "feature.status_changed" }
    sequence(:delivery_id) { |n| "delivery-#{n}" }
  end
end
