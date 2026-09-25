require "rails_helper"

RSpec.describe Analysis::Truncate do
  def big_context(feature_titles: [], feature_files: [], feature_description: "desc")
    {
      "hackathon" => { "name" => "H" },
      "milestones" => [],
      "objectives" => [],
      "unattributed" => { "count" => 500, "titles" => Array.new(10) { "x" * 190 } },
      "features" => [
        {
          "key" => "F-1",
          "description" => feature_description,
          "activity" => { "total" => { "titles" => feature_titles, "files" => feature_files } }
        }
      ],
      "deterministic_alerts" => []
    }
  end

  it "does not touch the context if it already fits the budget" do
    context = big_context
    expect(described_class.call(context)).to eq(context)
  end

  it "removes activity titles first if it does not fit" do
    huge_titles = Array.new(200) { "x" * 190 }
    context = big_context(feature_titles: huge_titles)

    result = described_class.call(context)

    expect(result["unattributed"]["titles"]).to be_empty
    expect(result["features"].first["activity"]["total"]["titles"]).to be_empty
  end

  it "if that is not enough, removes the file paths" do
    huge_files = Array.new(200) { "path/" + ("x" * 190) }
    context = big_context(feature_files: huge_files)

    result = described_class.call(context)

    expect(result["features"].first["activity"]["total"]["files"]).to be_empty
  end

  it "as a last resort, cuts the feature descriptions" do
    context = big_context(feature_description: "d" * 40_000)

    result = described_class.call(context)

    expect(result["features"].first["description"].length).to eq(100)
  end
end
