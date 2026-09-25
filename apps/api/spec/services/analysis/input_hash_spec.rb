require "rails_helper"

RSpec.describe Analysis::InputHash do
  it "ignores the now field" do
    a = { "hackathon" => { "now" => "2026-01-01T00:00:00Z", "name" => "H" } }
    b = { "hackathon" => { "now" => "2026-01-01T05:00:00Z", "name" => "H" } }

    expect(described_class.call(a)).to eq(described_class.call(b))
  end

  it "rounds hours_remaining to the hour" do
    a = { "milestones" => [ { "hours_remaining" => 2.1 } ] }
    b = { "milestones" => [ { "hours_remaining" => 2.4 } ] }

    expect(described_class.call(a)).to eq(described_class.call(b))
  end

  it "changes if anything other than now or the hour rounding changes" do
    a = { "features" => [ { "title" => "A" } ] }
    b = { "features" => [ { "title" => "B" } ] }

    expect(described_class.call(a)).not_to eq(described_class.call(b))
  end
end
