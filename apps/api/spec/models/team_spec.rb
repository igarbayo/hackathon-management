require "rails_helper"

RSpec.describe Team, type: :model do
  it "genera un código único de 8 caracteres al crear" do
    team = create(:team)

    expect(team.code).to match(/\A[23456789ABCDEFGHJKMNPQRSTVWXYZ]{8}\z/)
  end

  it "formatea el código como XXXX-XXXX" do
    team = create(:team, code: "ABCD1234".tr("01", "23"))

    expect(team.formatted_code).to eq("#{team.code[0, 4]}-#{team.code[4, 4]}")
  end

  it "no permite dos equipos con el mismo código" do
    existing = create(:team)
    duplicate = build(:team, code: existing.code)

    expect(duplicate).not_to be_valid
  end

  it "valida el hackathon embebido" do
    team = build(:team)
    team.hackathon.timezone = "No/Existe"

    expect(team).not_to be_valid
  end

  describe "#next_feature_number! / #next_objective_number!" do
    it "incrementa de forma atómica y nunca repite un número" do
      team = create(:team)

      numbers = Array.new(20) { team.next_feature_number! }

      expect(numbers).to eq(numbers.uniq)
      expect(numbers).to eq((1..20).to_a)
    end

    it "lleva contadores independientes para features y objetivos" do
      team = create(:team)

      expect(team.next_feature_number!).to eq(1)
      expect(team.next_objective_number!).to eq(1)
      expect(team.next_feature_number!).to eq(2)
    end

    it "no repite número bajo llamadas concurrentes (uso de find_one_and_update atómico)" do
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
    it "marca el equipo como borrado y revoca todos sus tokens" do
      team = create(:team)
      pat = create(:access_token, team: team)
      integration = create(:access_token, :integration, team: team)

      team.soft_delete!

      expect(team.reload).to be_deleted
      expect([ pat.reload, integration.reload ].map(&:revoke_reason)).to all(eq("team_deleted"))
    end
  end
end
