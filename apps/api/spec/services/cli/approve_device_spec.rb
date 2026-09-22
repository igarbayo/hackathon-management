require "rails_helper"

RSpec.describe Cli::ApproveDevice do
  it "aprueba un código pendiente y le asigna equipo, membership y nivel" do
    membership = create(:membership)
    record = create(:device_authorization)

    result = described_class.call(team: membership.team, membership: membership, user_code: record.user_code, privacy_level: "summaries")

    expect(result.status).to eq("approved")
    expect(result.team_id).to eq(membership.team.id)
    expect(result.membership_id).to eq(membership.id)
    expect(result.privacy_level).to eq("summaries")
  end

  it "acepta el user_code con guion (como se muestra en pantalla)" do
    membership = create(:membership)
    record = create(:device_authorization)

    result = described_class.call(team: membership.team, membership: membership, user_code: record.formatted_user_code, privacy_level: "metadata")

    expect(result.status).to eq("approved")
  end

  it "404 si el user_code no existe" do
    membership = create(:membership)

    expect { described_class.call(team: membership.team, membership: membership, user_code: "ZZZZ-ZZZZ", privacy_level: "metadata") }
      .to raise_error(ApiError::NotFound)
  end

  it "400 si ya no está pending" do
    membership = create(:membership)
    record = create(:device_authorization, status: "denied")

    expect { described_class.call(team: membership.team, membership: membership, user_code: record.user_code, privacy_level: "metadata") }
      .to raise_error(ApiError::BadRequest)
  end

  it "400 si ha caducado" do
    membership = create(:membership)
    record = create(:device_authorization, expires_at: 1.minute.ago)

    expect { described_class.call(team: membership.team, membership: membership, user_code: record.user_code, privacy_level: "metadata") }
      .to raise_error(ApiError::BadRequest)
  end

  it "409 si el código ya trae un equipo distinto (vino con --team en otro)" do
    other_team = create(:team)
    membership = create(:membership)
    record = create(:device_authorization, team: other_team)

    expect { described_class.call(team: membership.team, membership: membership, user_code: record.user_code, privacy_level: "metadata") }
      .to raise_error(ApiError::Conflict)
  end

  it "400 si el nivel de privacidad no es válido" do
    membership = create(:membership)
    record = create(:device_authorization)

    expect { described_class.call(team: membership.team, membership: membership, user_code: record.user_code, privacy_level: "nope") }
      .to raise_error(ApiError::BadRequest)
  end
end
