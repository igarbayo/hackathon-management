require "rails_helper"

RSpec.describe Analysis::PostValidate do
  it "añade uncovered para los objetivos que faltan" do
    team = create(:team)
    o1 = create(:objective, team: team)
    o2 = create(:objective, team: team)

    result = described_class.call(data: { "coverage" => [{ "objective_key" => o1.key, "status" => "covered", "feature_keys" => [], "rationale" => "ok" }] }, team: team)

    keys = result["coverage"].map { |c| c["objective_key"] }
    expect(keys).to contain_exactly(o1.key, o2.key)
    missing = result["coverage"].find { |c| c["objective_key"] == o2.key }
    expect(missing["status"]).to eq("uncovered")
    expect(missing["rationale"]).to eq("no evaluado")
  end

  it "descarta duplicados de coverage, quedándose con el primero" do
    team = create(:team)
    objective = create(:objective, team: team)

    result = described_class.call(
      data: { "coverage" => [
        { "objective_key" => objective.key, "status" => "covered", "feature_keys" => [], "rationale" => "primero" },
        { "objective_key" => objective.key, "status" => "partial", "feature_keys" => [], "rationale" => "segundo" }
      ] },
      team: team
    )

    expect(result["coverage"].size).to eq(1)
    expect(result["coverage"].first["rationale"]).to eq("primero")
  end

  it "quita claves de feature que no existen en el equipo" do
    team = create(:team)
    objective = create(:objective, team: team)
    feature = create(:feature, team: team)

    result = described_class.call(
      data: { "coverage" => [{ "objective_key" => objective.key, "status" => "covered", "feature_keys" => [feature.key, "F-999"], "rationale" => "x" }] },
      team: team
    )

    expect(result["coverage"].first["feature_keys"]).to eq([feature.key])
  end

  it "orphan_features solo incluye features no descartadas" do
    team = create(:team)
    active = create(:feature, team: team)
    discarded = create(:feature, team: team, status: "discarded")

    result = described_class.call(
      data: { "orphan_features" => [
        { "feature_key" => active.key, "rationale" => "x", "recommendation" => "keep", "suggested_objective_key" => nil },
        { "feature_key" => discarded.key, "rationale" => "x", "recommendation" => "keep", "suggested_objective_key" => nil }
      ] },
      team: team
    )

    expect(result["orphan_features"].map { |o| o["feature_key"] }).to eq([active.key])
  end

  it "descarta un status o severity inválidos con un valor por defecto seguro" do
    team = create(:team)
    objective = create(:objective, team: team)

    result = described_class.call(
      data: {
        "coverage" => [{ "objective_key" => objective.key, "status" => "hackeado", "feature_keys" => [], "rationale" => "x" }],
        "risks" => [{ "severity" => "catastrofico", "kind" => "raro", "description" => "x", "related_keys" => [] }]
      },
      team: team
    )

    expect(result["coverage"].first["status"]).to eq("uncovered")
    expect(result["risks"].first["severity"]).to eq("low")
    expect(result["risks"].first["kind"]).to eq("other")
  end
end
