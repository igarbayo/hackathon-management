FactoryBot.define do
  factory :webhook_delivery do
    sequence(:delivery_id) { |n| "gh-delivery-#{n}" }
    event { "push" }
  end
end
