require "rails_helper"

RSpec.describe Cli::CreateDeviceAuthorization do
  it "crea un DeviceAuthorization pendiente y devuelve el device_code en claro una sola vez" do
    result = described_class.call

    expect(result.device_code).to be_present
    expect(result.record).to be_persisted
    expect(result.record.status).to eq("pending")
    expect(result.record.device_code_digest).to eq(Digest::SHA256.hexdigest(result.device_code))
  end

  it "resuelve el equipo si viene team_code" do
    team = create(:team)

    result = described_class.call(team_code: team.code)

    expect(result.record.team_id).to eq(team.id)
  end

  it "deja team_id a nil si el team_code no existe" do
    result = described_class.call(team_code: "NOEXISTE")

    expect(result.record.team_id).to be_nil
  end
end
