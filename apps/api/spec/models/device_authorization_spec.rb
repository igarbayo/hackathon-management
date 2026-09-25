require "rails_helper"

RSpec.describe DeviceAuthorization, type: :model do
  it "generates a unique 8-character user_code" do
    record = create(:device_authorization)

    expect(record.user_code).to match(/\A[23456789ABCDEFGHJKMNPQRSTVWXYZ]{8}\z/)
  end

  it "expires after 15 minutes by default" do
    record = create(:device_authorization)

    expect(record.expires_at).to be_within(5.seconds).of(15.minutes.from_now)
  end

  it "does not allow two with the same device_code_digest" do
    create(:device_authorization, device_code_digest: "dup")
    duplicate = build(:device_authorization, device_code_digest: "dup")

    expect(duplicate).not_to be_valid
  end
end
