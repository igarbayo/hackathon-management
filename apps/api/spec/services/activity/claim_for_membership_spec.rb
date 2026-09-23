require "rails_helper"

RSpec.describe Activity::ClaimForMembership do
  let(:team) { create(:team) }

  def commit(team: self.team, **actor)
    actor = actor.transform_keys(&:to_s)
    create(:activity_event, :github_commit, team: team, actor: { "user_id" => nil, "display" => actor["author_name"] }.merge(actor))
  end

  it "asigna los commits sin usuario que coinciden con el login o el email de la cuenta" do
    by_login = commit("github_login" => "Grace", "author_name" => "Grace H")
    by_email = commit("email" => "grace@example.com", "author_name" => "G")
    by_noreply = commit("email" => "123+grace@users.noreply.github.com")
    other = commit("github_login" => "otra", "email" => "otra@example.com")
    user = create(:user, email: "grace@example.com", github_login: "grace")
    membership = Membership.create!(team: team, user: user, role: "member", display_name: "Grace")

    expect(described_class.call(membership)).to eq(3)

    [ by_login, by_email, by_noreply ].each do |event|
      expect(event.reload.actor).to include("user_id" => user.id.to_s, "membership_id" => membership.id.to_s, "display" => "Grace", "mapped_by" => "auto")
    end
    expect(other.reload.actor["user_id"]).to be_nil
  end

  it "usa las git_identities del miembro" do
    event = commit("email" => "grace@work.example.com")
    membership = create(:membership, team: team, git_identities: [ "grace@work.example.com" ])

    described_class.call(membership)

    expect(event.reload.actor["membership_id"]).to eq(membership.id.to_s)
  end

  it "nunca quita un evento que ya tiene usuario ni devuelve uno marcado como 'No son míos'" do
    user = create(:user, github_login: "grace")
    membership = create(:membership, team: team, user: user)
    taken = commit("github_login" => "grace", "user_id" => "otro", "membership_id" => "otro")
    unclaimed = commit("github_login" => "grace", "unclaimed_by" => [ membership.id.to_s ])

    described_class.call(membership)

    expect(taken.reload.actor["user_id"]).to eq("otro")
    expect(unclaimed.reload.actor["user_id"]).to be_nil
  end

  it "solo toca eventos de su equipo (RNF-SEC-001)" do
    other_team_event = commit(team: create(:team), "github_login" => "grace")
    membership = create(:membership, team: team, user: create(:user, github_login: "grace"))

    described_class.call(membership)

    expect(other_team_event.reload.actor["user_id"]).to be_nil
  end

  it "se lanza al unirse al equipo (job en after_create)" do
    event = commit("github_login" => "grace")
    user = create(:user, github_login: "grace")

    Teams::Join.call(user: user, code: team.code)
    Activity::ClaimForMembershipJob.drain

    expect(event.reload.actor["user_id"]).to eq(user.id.to_s)
  end

  it "se lanza cuando la persona vincula GitHub después (cambia github_login)" do
    membership = create(:membership, team: team)
    Activity::ClaimForMembershipJob.drain
    event = commit("github_login" => "grace")

    membership.user.update!(github_login: "grace")
    Activity::ClaimForMembershipJob.drain

    expect(event.reload.actor["membership_id"]).to eq(membership.id.to_s)
  end
end
