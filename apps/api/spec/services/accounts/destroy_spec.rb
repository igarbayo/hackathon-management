require "rails_helper"

RSpec.describe Accounts::Destroy do
  let(:membership) { create(:membership, :owner) }
  let(:team) { membership.team }
  let(:user) { membership.user }

  before { create(:membership, :owner, team: team) }

  it "revoca los PAT y tokens OAuth del usuario, pero no los de integración del equipo" do
    pat = create(:access_token, team: team, membership: membership, user_id: user.id)
    integration = create(:access_token, :integration, team: team, created_by_id: user.id)

    described_class.call(user: user)

    expect(pat.reload.revoked_at).to be_present
    expect(pat.revoke_reason).to eq("account_deleted")
    expect(integration.reload.revoked_at).to be_nil
  end

  it "borra sus eventos de Claude Code y MCP" do
    create(:activity_event, :claude_turn, team: team, actor: { "user_id" => user.id.to_s, "membership_id" => membership.id.to_s })

    described_class.call(user: user)

    expect(ActivityEvent.where(team_id: team.id, source: "claude_code").count).to eq(0)
  end

  it "anonimiza el actor de sus eventos de GitHub y conserva el login" do
    event = create(:activity_event, :github_commit, team: team,
                   actor: { "user_id" => user.id.to_s, "membership_id" => membership.id.to_s, "display" => "Ana", "github_login" => "ana" })

    described_class.call(user: user)

    expect(event.reload.actor).to include(
      "user_id" => nil, "membership_id" => nil, "display" => "Usuario eliminado", "github_login" => "ana"
    )
    expect(User.where(id: user.id).first).to be_nil
  end

  it "no toca nada si es el único owner de un equipo con más miembros" do
    solo_owner = create(:membership, :owner)
    create(:membership, team: solo_owner.team)
    pat = create(:access_token, team: solo_owner.team, membership: solo_owner, user_id: solo_owner.user_id)

    expect { described_class.call(user: solo_owner.user) }.to raise_error(ApiError::Conflict)
    expect(pat.reload.revoked_at).to be_nil
  end
end
