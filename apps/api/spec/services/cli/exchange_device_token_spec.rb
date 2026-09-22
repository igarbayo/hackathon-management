require "rails_helper"

RSpec.describe Cli::ExchangeDeviceToken do
  it "authorization_pending si todavía no se ha aprobado" do
    creation = Cli::CreateDeviceAuthorization.call

    result = described_class.call(device_code: creation.device_code)

    expect(result.outcome).to eq(:authorization_pending)
  end

  it "access_denied si se rechazó" do
    creation = Cli::CreateDeviceAuthorization.call
    creation.record.update!(status: "denied")

    result = described_class.call(device_code: creation.device_code)

    expect(result.outcome).to eq(:access_denied)
  end

  it "expired_token si pasaron los 15 minutos" do
    creation = Cli::CreateDeviceAuthorization.call
    creation.record.update!(expires_at: 1.minute.ago)

    result = described_class.call(device_code: creation.device_code)

    expect(result.outcome).to eq(:expired_token)
  end

  it "invalid_grant si el device_code no existe" do
    result = described_class.call(device_code: "no-existe")

    expect(result.outcome).to eq(:invalid_grant)
  end

  it "mintea un token hb_mt_ una sola vez y guarda solo su hash" do
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
