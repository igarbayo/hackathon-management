require "rails_helper"

RSpec.describe Analysis::Lock do
  it "solo un lock a la vez por equipo" do
    expect(described_class.acquire("team-1")).to be true
    expect(described_class.acquire("team-1")).to be false
  end

  it "libera el lock" do
    described_class.acquire("team-2")
    described_class.release("team-2")

    expect(described_class.acquire("team-2")).to be true
  end

  it "no bloquea equipos distintos" do
    expect(described_class.acquire("team-3")).to be true
    expect(described_class.acquire("team-4")).to be true
  end
end
