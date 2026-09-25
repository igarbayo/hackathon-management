require "rails_helper"

RSpec.describe Repository, type: :model do
  it "an active repository belongs to a single team (ADR-0007)" do
    create(:repository, github_repo_id: 555, active: true)
    other_team_same_repo = build(:repository, github_repo_id: 555, active: true)

    expect(other_team_same_repo).not_to be_valid
    expect(other_team_same_repo.errors[:base]).to be_present
  end

  it "allows the same github_repo_id if the first one is inactive" do
    create(:repository, github_repo_id: 777, active: false)
    other_team_same_repo = build(:repository, github_repo_id: 777, active: true)

    expect(other_team_same_repo).to be_valid
  end

  describe "#current_import (RF-GH-025)" do
    it "returns the import as is while it is on time or finished" do
      running = { "status" => "running", "expires_at" => 5.minutes.from_now.utc.iso8601 }
      done = { "status" => "done", "commits" => 3 }

      expect(build(:repository, last_import: running).current_import).to eq(running)
      expect(build(:repository, last_import: done).current_import).to eq(done)
      expect(build(:repository, last_import: nil).current_import).to be_nil
    end

    it "reports as failed an import stuck past its deadline" do
      stuck = { "status" => "queued", "expires_at" => 1.minute.ago.utc.iso8601 }

      expect(build(:repository, last_import: stuck).current_import).to eq("status" => "failed", "reason" => "stalled")
    end

    it "reports as failed a pending import from before deadlines existed" do
      expect(build(:repository, last_import: { "status" => "running" }).current_import)
        .to eq("status" => "failed", "reason" => "stalled")
    end
  end
end
