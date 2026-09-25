require "rails_helper"

RSpec.describe Accounts::Destroy do
  let(:membership) { create(:membership, :owner) }
  let(:team) { membership.team }
  let(:user) { membership.user }

  before { create(:membership, :owner, team: team) }

  it "revokes the user's PATs and OAuth tokens, but not the team's integration tokens" do
    pat = create(:access_token, team: team, membership: membership, user_id: user.id)
    integration = create(:access_token, :integration, team: team, created_by_id: user.id)

    described_class.call(user: user)

    expect(pat.reload.revoked_at).to be_present
    expect(pat.revoke_reason).to eq("account_deleted")
    expect(integration.reload.revoked_at).to be_nil
  end

  it "deletes their Claude Code and MCP events" do
    create(:activity_event, :claude_turn, team: team, actor: { "user_id" => user.id.to_s, "membership_id" => membership.id.to_s })

    described_class.call(user: user)

    expect(ActivityEvent.where(team_id: team.id, source: "claude_code").count).to eq(0)
  end

  it "anonymizes the actor of their GitHub events and keeps the login" do
    event = create(:activity_event, :github_commit, team: team,
                   actor: { "user_id" => user.id.to_s, "membership_id" => membership.id.to_s, "display" => "Ana", "github_login" => "ana",
                              "email" => "ana@example.com", "author_name" => "Ana" })

    described_class.call(user: user)

    expect(event.reload.actor).to include(
      "user_id" => nil, "membership_id" => nil, "display" => "Deleted user", "github_login" => "ana",
      "email" => nil, "author_name" => nil
    )
    expect(User.where(id: user.id).first).to be_nil
  end

  it "touches nothing if they are the only owner of a team with more members" do
    solo_owner = create(:membership, :owner)
    create(:membership, team: solo_owner.team)
    pat = create(:access_token, team: solo_owner.team, membership: solo_owner, user_id: solo_owner.user_id)

    expect { described_class.call(user: solo_owner.user) }.to raise_error(ApiError::Conflict)
    expect(pat.reload.revoked_at).to be_nil
  end
end
