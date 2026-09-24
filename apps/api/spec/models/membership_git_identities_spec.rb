require "rails_helper"

RSpec.describe Membership, "git_identities" do
  it "normaliza a minúsculas y quita duplicados y vacíos" do
    membership = create(:membership, git_identities: [ " Ada@Example.com ", "ada@example.com", "", "AdaDev" ])

    expect(membership.git_identities).to eq([ "ada@example.com", "adadev" ])
  end

  it "no deja que una identidad sea de dos miembros del mismo equipo" do
    first = create(:membership, git_identities: [ "ada@example.com" ])
    second = build(:membership, team: first.team, git_identities: [ "ADA@example.com" ])

    expect(second).not_to be_valid
    expect(second.errors[:git_identities]).to be_present
  end

  it "encola la asignación retroactiva al añadir identidades" do
    membership = create(:membership)
    Activity::ClaimForMembershipJob.clear

    membership.update!(display_name: "Otro nombre")
    expect(Activity::ClaimForMembershipJob.jobs).to be_empty

    membership.update!(git_identities: [ "ada@example.com" ])
    expect(Activity::ClaimForMembershipJob.jobs.size).to eq(1)
  end
end
