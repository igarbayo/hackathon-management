require "rails_helper"

RSpec.describe Attribution::ConventionJob do
  let(:team) { create(:team) }

  it "se encola automáticamente al crear un evento de un kind atribuible" do
    create(:activity_event, :github_commit, team: team, title: "algo")

    expect(described_class.jobs.size).to eq(1)
  end

  it "no se encola para kinds no atribuibles (p. ej. system)" do
    create(:activity_event, team: team, source: "system", kind: "member_joined")

    expect(described_class.jobs).to be_empty
  end

  it "capa 1: atribuye por convención al ejecutarse" do
    feature = create(:feature, team: team)
    event = create(:activity_event, :github_commit, team: team, title: "Arregla F-#{feature.number}")

    described_class.drain

    event.reload
    expect(event.attribution.feature_id).to eq(feature.id)
    expect(event.attribution.method).to eq("convention")
    expect(event.attribution.status).to eq("confirmed")
  end

  it "capa 2: si no hay convención, prueba la rama conocida" do
    feature = create(:feature, team: team, branch_names: [ "mi-rama" ])
    event = create(:activity_event, :github_commit, team: team, title: "sin clave", branch: "mi-rama")

    described_class.drain

    event.reload
    expect(event.attribution.feature_id).to eq(feature.id)
    expect(event.attribution.method).to eq("branch")
  end

  it "sin convención ni rama conocida, el evento queda sin atribución" do
    create(:activity_event, :github_commit, team: team, title: "sin pistas")

    described_class.drain

    event = ActivityEvent.where(team_id: team.id).first
    expect(event.attribution).to be_nil
  end

  it "es idempotente: no toca un evento que ya tiene atribución" do
    other_feature = create(:feature, team: team)
    feature = create(:feature, team: team)
    event = create(:activity_event, :github_commit, team: team, title: "F-#{feature.number}")
    event.build_attribution(feature_id: other_feature.id, method: "manual", status: "confirmed")
    event.save!

    described_class.new.perform(event.id.to_s)

    expect(event.reload.attribution.feature_id).to eq(other_feature.id)
  end

  it "guarda mentioned_feature_keys aunque no se pueda atribuir" do
    create(:activity_event, :github_commit, team: team, title: "menciona F-777")

    described_class.drain

    event = ActivityEvent.where(team_id: team.id).first
    expect(event.mentioned_feature_keys).to eq([ "F-777" ])
  end
end
