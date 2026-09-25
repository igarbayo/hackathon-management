require "rails_helper"

RSpec.describe Cli::ApproveDevice do
  it "approves a pending code and gives it team, membership and level" do
    membership = create(:membership)
    record = create(:device_authorization)

    result = described_class.call(team: membership.team, membership: membership, user_code: record.user_code, privacy_level: "summaries")

    expect(result.status).to eq("approved")
    expect(result.team_id).to eq(membership.team.id)
    expect(result.membership_id).to eq(membership.id)
    expect(result.privacy_level).to eq("summaries")
  end

  it "accepts the user_code with a hyphen (as shown on screen)" do
    membership = create(:membership)
    record = create(:device_authorization)

    result = described_class.call(team: membership.team, membership: membership, user_code: record.formatted_user_code, privacy_level: "metadata")

    expect(result.status).to eq("approved")
  end

  it "404 if the user_code does not exist" do
    membership = create(:membership)

    expect { described_class.call(team: membership.team, membership: membership, user_code: "ZZZZ-ZZZZ", privacy_level: "metadata") }
      .to raise_error(ApiError::NotFound)
  end

  it "400 if it is no longer pending" do
    membership = create(:membership)
    record = create(:device_authorization, status: "denied")

    expect { described_class.call(team: membership.team, membership: membership, user_code: record.user_code, privacy_level: "metadata") }
      .to raise_error(ApiError::BadRequest)
  end

  it "400 if it has expired" do
    membership = create(:membership)
    record = create(:device_authorization, expires_at: 1.minute.ago)

    expect { described_class.call(team: membership.team, membership: membership, user_code: record.user_code, privacy_level: "metadata") }
      .to raise_error(ApiError::BadRequest)
  end

  it "409 if the code already has a different team (it came with --team for another one)" do
    other_team = create(:team)
    membership = create(:membership)
    record = create(:device_authorization, team: other_team)

    expect { described_class.call(team: membership.team, membership: membership, user_code: record.user_code, privacy_level: "metadata") }
      .to raise_error(ApiError::Conflict)
  end

  it "400 if the privacy level is not valid" do
    membership = create(:membership)
    record = create(:device_authorization)

    expect { described_class.call(team: membership.team, membership: membership, user_code: record.user_code, privacy_level: "nope") }
      .to raise_error(ApiError::BadRequest)
  end
end
