require "rails_helper"

RSpec.describe Analysis::InputHash do
  it "ignora el campo now" do
    a = { "hackathon" => { "now" => "2026-01-01T00:00:00Z", "name" => "H" } }
    b = { "hackathon" => { "now" => "2026-01-01T05:00:00Z", "name" => "H" } }

    expect(described_class.call(a)).to eq(described_class.call(b))
  end

  it "redondea hours_remaining a la hora" do
    a = { "milestones" => [{ "hours_remaining" => 2.1 }] }
    b = { "milestones" => [{ "hours_remaining" => 2.4 }] }

    expect(described_class.call(a)).to eq(described_class.call(b))
  end

  it "cambia si cambia algo que no sea now o el redondeo de horas" do
    a = { "features" => [{ "title" => "A" }] }
    b = { "features" => [{ "title" => "B" }] }

    expect(described_class.call(a)).not_to eq(described_class.call(b))
  end
end
