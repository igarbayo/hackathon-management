require "rails_helper"

RSpec.describe WebhookDelivery, type: :model do
  it "the delivery_id is unique (GitHub webhook idempotency)" do
    create(:webhook_delivery, delivery_id: "abc-123")
    duplicate = build(:webhook_delivery, delivery_id: "abc-123")

    expect(duplicate).not_to be_valid
  end
end
