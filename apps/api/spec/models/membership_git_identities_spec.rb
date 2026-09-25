require "rails_helper"

RSpec.describe Membership, "git_identities" do
  it "lowercases and removes duplicates and blanks" do
    membership = create(:membership, git_identities: [ " Ada@Example.com ", "ada@example.com", "", "AdaDev" ])

    expect(membership.git_identities).to eq([ "ada@example.com", "adadev" ])
  end

  it "does not let an identity belong to two members of the same team" do
    first = create(:membership, git_identities: [ "ada@example.com" ])
    second = build(:membership, team: first.team, git_identities: [ "ADA@example.com" ])

    expect(second).not_to be_valid
    expect(second.errors[:git_identities]).to be_present
  end

  it "queues the retroactive assignment when identities are added" do
    membership = create(:membership)
    Activity::ClaimForMembershipJob.clear

    membership.update!(display_name: "Another name")
    expect(Activity::ClaimForMembershipJob.jobs).to be_empty

    membership.update!(git_identities: [ "ada@example.com" ])
    expect(Activity::ClaimForMembershipJob.jobs.size).to eq(1)
  end
end
