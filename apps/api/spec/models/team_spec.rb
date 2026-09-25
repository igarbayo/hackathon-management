require "rails_helper"

RSpec.describe Team, type: :model do
  it "generates a unique 8-character code on create" do
    team = create(:team)

    expect(team.code).to match(/\A[23456789ABCDEFGHJKMNPQRSTVWXYZ]{8}\z/)
  end

  it "formats the code as XXXX-XXXX" do
    team = create(:team, code: "ABCD1234".tr("01", "23"))

    expect(team.formatted_code).to eq("#{team.code[0, 4]}-#{team.code[4, 4]}")
  end

  it "does not allow two teams with the same code" do
    existing = create(:team)
    duplicate = build(:team, code: existing.code)

    expect(duplicate).not_to be_valid
  end

  it "validates the embedded hackathon" do
    team = build(:team)
    team.hackathon.timezone = "No/Existe"

    expect(team).not_to be_valid
  end

  describe "#next_feature_number! / #next_objective_number!" do
    it "increments atomically and never repeats a number" do
      team = create(:team)

      numbers = Array.new(20) { team.next_feature_number! }

      expect(numbers).to eq(numbers.uniq)
      expect(numbers).to eq((1..20).to_a)
    end

    it "keeps separate counters for features and objectives" do
      team = create(:team)

      expect(team.next_feature_number!).to eq(1)
      expect(team.next_objective_number!).to eq(1)
      expect(team.next_feature_number!).to eq(2)
    end

    it "does not repeat a number under concurrent calls (atomic find_one_and_update)" do
      team = create(:team)

      numbers = []
      mutex = Mutex.new

      threads = Array.new(10) do
        Thread.new do
          number = team.next_feature_number!
          mutex.synchronize { numbers << number }
        end
      end
      threads.each(&:join)

      expect(numbers.sort).to eq((1..10).to_a)
    end
  end

  describe "#soft_delete! (RF-TEAM-009)" do
    it "marks the team as deleted and revokes all its tokens" do
      team = create(:team)
      pat = create(:access_token, team: team)
      integration = create(:access_token, :integration, team: team)

      team.soft_delete!

      expect(team.reload).to be_deleted
      expect([ pat.reload, integration.reload ].map(&:revoke_reason)).to all(eq("team_deleted"))
    end
  end
end
