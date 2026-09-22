require "rails_helper"

RSpec.describe WebhookDelivery, type: :model do
  it "el delivery_id es único (idempotencia de webhooks de GitHub)" do
    create(:webhook_delivery, delivery_id: "abc-123")
    duplicate = build(:webhook_delivery, delivery_id: "abc-123")

    expect(duplicate).not_to be_valid
  end
end
