require "rails_helper"

RSpec.describe Github::Normalize::Branch do
  let(:team) { create(:team) }
  let(:repository) { create(:repository, team: team) }

  it "crea branch_created para ref_type branch" do
    described_class.call(team: team, repository: repository, kind: "branch_created",
                          payload: { "ref" => "f-12-login", "ref_type" => "branch", "sender" => { "login" => "octocat" } })

    event = ActivityEvent.where(team_id: team.id).first
    expect(event.kind).to eq("branch_created")
    expect(event.branch).to eq("f-12-login")
  end

  it "ignora ref_type tag" do
    described_class.call(team: team, repository: repository, kind: "branch_created",
                          payload: { "ref" => "v1.0.0", "ref_type" => "tag" })

    expect(ActivityEvent.count).to eq(0)
  end
end
