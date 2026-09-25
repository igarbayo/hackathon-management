require "rails_helper"

RSpec.describe Github::MapAuthor do
  let(:team) { create(:team) }

  it "maps by github_login" do
    user = create(:user, github_login: "adalovelace")
    membership = create(:membership, team: team, user: user)

    result = described_class.call(team: team, login: "adalovelace", email: nil, display_name: "Ada")

    expect(result["user_id"]).to eq(membership.user_id.to_s)
  end

  it "maps by email if there is no login" do
    user = create(:user, email: "ada@example.com")
    membership = create(:membership, team: team, user: user)

    result = described_class.call(team: team, login: nil, email: "ADA@example.com", display_name: nil)

    expect(result["user_id"]).to eq(membership.user_id.to_s)
  end

  it "maps by git_identities if the email does not match the account's" do
    membership = create(:membership, team: team, git_identities: [ "ada@work.example.com" ])

    result = described_class.call(team: team, login: nil, email: "ada@work.example.com", display_name: nil)

    expect(result["user_id"]).to eq(membership.user_id.to_s)
  end

  it "extracts the login from a GitHub noreply email and maps it" do
    user = create(:user, github_login: "adalovelace")
    membership = create(:membership, team: team, user: user)

    result = described_class.call(team: team, login: nil, email: "12345+adalovelace@users.noreply.github.com", display_name: nil)

    expect(result["user_id"]).to eq(membership.user_id.to_s)
  end

  it "with no match, leaves user_id nil and uses the display name" do
    result = described_class.call(team: team, login: "unknown", email: "x@example.com", display_name: "Unknown")

    expect(result["user_id"]).to be_nil
    expect(result["display"]).to eq("Unknown")
    expect(result["github_login"]).to eq("unknown")
  end

  it "always keeps the author's identity, member or not (ADR-0018)" do
    result = described_class.call(team: team, login: "Grace", email: "Grace@Example.com", display_name: "Grace Hopper")

    expect(result).to include("github_login" => "Grace", "email" => "grace@example.com", "author_name" => "Grace Hopper")
    expect(result["mapped_by"]).to be_nil
  end

  it "compares the login case-insensitively and marks mapped_by auto" do
    user = create(:user, github_login: "AdaLovelace")
    membership = create(:membership, team: team, user: user)

    result = described_class.call(team: team, login: "adalovelace", email: nil, display_name: nil)

    expect(result["membership_id"]).to eq(membership.id.to_s)
    expect(result["mapped_by"]).to eq("auto")
  end

  it "maps by a login stored in git_identities" do
    membership = create(:membership, team: team, git_identities: [ "ada-alt" ])

    result = described_class.call(team: team, login: "Ada-Alt", email: nil, display_name: nil)

    expect(result["membership_id"]).to eq(membership.id.to_s)
  end
end
