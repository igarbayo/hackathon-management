require "rails_helper"

RSpec.describe Analysis::BuildContext do
  it "incluye hackathon, milestones, objetivos, features y alertas deterministas" do
    team = create(:team)
    objective = create(:objective, team: team)
    feature = create(:feature, team: team, objective_ids: [objective.id])
    create(:milestone, team: team)

    context = described_class.call(team)

    expect(context["hackathon"]["name"]).to eq(team.hackathon.name)
    expect(context["objectives"].first["key"]).to eq(objective.key)
    expect(context["features"].first["key"]).to eq(feature.key)
    expect(context["features"].first["objective_keys"]).to eq([objective.key])
    expect(context["milestones"]).not_to be_empty
    expect(context["deterministic_alerts"]).to be_an(Array)
  end

  it "no incluye objetivos archivados" do
    team = create(:team)
    create(:objective, team: team, archived_at: Time.current)

    expect(described_class.call(team)["objectives"]).to be_empty
  end

  it "las features discarded solo llevan clave y título" do
    team = create(:team)
    feature = create(:feature, team: team, status: "discarded")

    json = described_class.call(team)["features"].first
    expect(json).to eq("key" => feature.key, "title" => feature.title, "status" => "discarded")
  end

  it "recorta el challenge_text a 6000 caracteres" do
    team = create(:team, hackathon: build(:hackathon, challenge_text: "a" * 7000))

    expect(described_class.call(team)["hackathon"]["challenge_text"].length).to eq(6000)
  end

  it "el contexto siempre pasa por Truncate y nunca supera el presupuesto" do
    team = create(:team)
    create(:feature, team: team)

    expect(Analysis::Truncate).to receive(:call).and_call_original
    described_class.call(team)
  end
end
