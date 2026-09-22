require "rails_helper"

RSpec.describe Feature, type: :model do
  it "asigna número y key de forma atómica al crear" do
    team = create(:team)
    first = create(:feature, team: team)
    second = create(:feature, team: team)

    expect(first.number).to eq(1)
    expect(first.key).to eq("F-1")
    expect(second.number).to eq(2)
  end

  it "calcula el score como pros menos contras" do
    feature = create(:feature)
    feature.arguments.create!(kind: "pro", text: "Más rápido", voter_ids: [BSON::ObjectId.new, BSON::ObjectId.new])
    feature.arguments.create!(kind: "con", text: "Más caro", voter_ids: [BSON::ObjectId.new])

    expect(feature.score).to eq(1)
  end

  it "un voto por usuario (invariante de negocio expresada en voter_ids)" do
    feature = create(:feature)
    user_id = BSON::ObjectId.new
    argument = feature.arguments.create!(kind: "pro", text: "Bien", voter_ids: [user_id])

    argument.add_to_set(voter_ids: user_id)
    argument.reload

    expect(argument.voter_ids.count(user_id)).to eq(1)
  end
end
