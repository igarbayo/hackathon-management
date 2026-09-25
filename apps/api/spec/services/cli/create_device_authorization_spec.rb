require "rails_helper"

RSpec.describe Cli::CreateDeviceAuthorization do
  it "creates a pending DeviceAuthorization and returns the plain device_code only once" do
    result = described_class.call

    expect(result.device_code).to be_present
    expect(result.record).to be_persisted
    expect(result.record.status).to eq("pending")
    expect(result.record.device_code_digest).to eq(Digest::SHA256.hexdigest(result.device_code))
  end

  it "resolves the team if team_code comes in" do
    team = create(:team)

    result = described_class.call(team_code: team.code)

    expect(result.record.team_id).to eq(team.id)
  end

  it "leaves team_id nil if the team_code does not exist" do
    result = described_class.call(team_code: "NOTEXIST")

    expect(result.record.team_id).to be_nil
  end
end
