require "rails_helper"

RSpec.describe "PATCH/DELETE /api/v1/teams/:team_id/me/claude_code", type: :request do
  it "changes the privacy level of your own link" do
    membership = create(:membership)
    membership.update!(claude_code_attributes: { token_digest: "d", token_prefix: "hb_mt_ab12", privacy_level: "metadata" })
    sign_in_as(membership.user)

    patch "/api/v1/teams/#{membership.team.id}/me/claude_code", params: { privacy_level: "off" }, headers: csrf_headers, as: :json

    expect(response).to have_http_status(:ok)
    expect(membership.reload.claude_code.privacy_level).to eq("off")
  end

  it "does not allow changing another member's link" do
    owner = create(:membership, :owner)
    other = create(:membership, team: owner.team)
    other.update!(claude_code_attributes: { token_digest: "d", token_prefix: "hb_mt_ab12", privacy_level: "metadata" })
    sign_in_as(owner.user)

    patch "/api/v1/teams/#{owner.team.id}/me/claude_code", params: { privacy_level: "off" }, headers: csrf_headers, as: :json

    expect(response).to have_http_status(:not_found)
    expect(other.reload.claude_code.privacy_level).to eq("metadata")
  end

  it "DELETE without purge revokes the token but keeps the events" do
    membership = create(:membership)
    membership.update!(claude_code_attributes: { token_digest: "d", token_prefix: "hb_mt_ab12", privacy_level: "metadata" })
    event = create(:activity_event, :claude_turn, team: membership.team, actor: { "membership_id" => membership.id.to_s })
    sign_in_as(membership.user)

    delete "/api/v1/teams/#{membership.team.id}/me/claude_code", headers: csrf_headers

    expect(response).to have_http_status(:no_content)
    expect(membership.reload.claude_code).to be_nil
    expect(ActivityEvent.where(id: event.id).first).to be_present
  end

  it "DELETE ?purge=true also deletes your own Claude Code events" do
    membership = create(:membership)
    membership.update!(claude_code_attributes: { token_digest: "d", token_prefix: "hb_mt_ab12", privacy_level: "metadata" })
    mine = create(:activity_event, :claude_turn, team: membership.team, actor: { "membership_id" => membership.id.to_s })
    other_membership = create(:membership, team: membership.team)
    others = create(:activity_event, :claude_turn, team: membership.team, actor: { "membership_id" => other_membership.id.to_s })
    sign_in_as(membership.user)

    delete "/api/v1/teams/#{membership.team.id}/me/claude_code?purge=true", headers: csrf_headers

    expect(response).to have_http_status(:no_content)
    expect(ActivityEvent.where(id: mine.id).first).to be_nil
    expect(ActivityEvent.where(id: others.id).first).to be_present
  end
end
