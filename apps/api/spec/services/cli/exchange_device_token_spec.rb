require "rails_helper"

RSpec.describe Cli::ExchangeDeviceToken do
  it "authorization_pending if it has not been approved yet" do
    creation = Cli::CreateDeviceAuthorization.call

    result = described_class.call(device_code: creation.device_code)

    expect(result.outcome).to eq(:authorization_pending)
  end

  it "access_denied if it was denied" do
    creation = Cli::CreateDeviceAuthorization.call
    creation.record.update!(status: "denied")

    result = described_class.call(device_code: creation.device_code)

    expect(result.outcome).to eq(:access_denied)
  end

  it "expired_token if the 15 minutes have passed" do
    creation = Cli::CreateDeviceAuthorization.call
    creation.record.update!(expires_at: 1.minute.ago)

    result = described_class.call(device_code: creation.device_code)

    expect(result.outcome).to eq(:expired_token)
  end

  it "invalid_grant if the device_code does not exist" do
    result = described_class.call(device_code: "does-not-exist")

    expect(result.outcome).to eq(:invalid_grant)
  end

  it "mints an hb_mt_ token only once and stores only its hash" do
    creation = Cli::CreateDeviceAuthorization.call
    membership = create(:membership)
    creation.record.update!(status: "approved", team: membership.team, membership: membership, privacy_level: "metadata")

    result = described_class.call(device_code: creation.device_code)

    expect(result.outcome).to eq(:ok)
    expect(result.token).to start_with("hb_mt_")

    membership.reload
    expect(membership.claude_code.token_digest).to eq(Digest::SHA256.hexdigest(result.token))
    expect(membership.claude_code.privacy_level).to eq("metadata")

    second_try = described_class.call(device_code: creation.device_code)
    expect(second_try.outcome).to eq(:invalid_grant)
  end
end
