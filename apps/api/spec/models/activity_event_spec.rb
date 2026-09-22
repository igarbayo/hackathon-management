require "rails_helper"

RSpec.describe ActivityEvent, type: :model do
  it "no permite un kind que no pertenezca al source" do
    event = build(:activity_event, source: "github", kind: "cc_turn")

    expect(event).not_to be_valid
    expect(event.errors[:kind]).to be_present
  end

  it "acepta un kind válido para claude_code" do
    event = build(:activity_event, :claude_turn)

    expect(event).to be_valid
  end

  it "el dedupe_key es único por equipo" do
    team = create(:team)
    create(:activity_event, team: team, dedupe_key: "gh:commit:abc")
    duplicate = build(:activity_event, team: team, dedupe_key: "gh:commit:abc")

    expect(duplicate).not_to be_valid
  end

  it "el mismo dedupe_key se puede repetir en equipos distintos" do
    create(:activity_event, dedupe_key: "gh:commit:same")
    other_team_event = build(:activity_event, dedupe_key: "gh:commit:same")

    expect(other_team_event).to be_valid
  end

  it "no admite más de 50 ficheros" do
    event = build(:activity_event, files: Array.new(51) { { path: "a.rb" } })

    expect(event).not_to be_valid
  end

  describe "attribution embebida" do
    it "exige feature_id salvo cuando el estado es rejected" do
      event = build(:activity_event)
      event.build_attribution(method: "convention", status: "confirmed")

      expect(event).not_to be_valid
      expect(event.attribution.errors[:feature_id]).to be_present
    end

    it "permite rejected sin feature_id" do
      event = build(:activity_event)
      event.build_attribution(method: "ai", status: "rejected", confidence: 0.4)

      expect(event).to be_valid
    end
  end
end
