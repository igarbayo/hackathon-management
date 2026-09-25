require "rails_helper"

RSpec.describe Attribution::ApplyConvention do
  let(:team) { create(:team) }

  def event_with(title: nil, summary: nil, branch: nil)
    build(:activity_event, :github_commit, team: team, title: title, summary: summary, branch: branch)
  end

  it "recognizes F-12, f-12, feat/f-12-login and [F-12]" do
    feature = create(:feature, team: team)

    %W[F-#{feature.number} f-#{feature.number} feat/f-#{feature.number}-login [F-#{feature.number}]].each do |text|
      result = described_class.call(event_with(title: text))
      expect(result.feature).to eq(feature), "expected to find the feature in #{text.inspect}"
    end
  end

  it "does not recognize ref-12 or F-123a" do
    create(:feature, team: team, number: 12)

    expect(described_class.call(event_with(title: "ref-12")).feature).to be_nil
    expect(described_class.call(event_with(title: "F-123a")).feature).to be_nil
  end

  it "prefers the title/summary over the branch" do
    feature_a = create(:feature, team: team)
    feature_b = create(:feature, team: team)

    result = described_class.call(event_with(title: "Fix F-#{feature_a.number}", branch: "f-#{feature_b.number}-something-else"))

    expect(result.feature).to eq(feature_a)
    expect(result.mentioned_keys).to contain_exactly(feature_a.key, feature_b.key)
  end

  it "ignores keys that do not exist in the team, but keeps them in mentioned_keys" do
    result = described_class.call(event_with(title: "Related to F-999"))

    expect(result.feature).to be_nil
    expect(result.mentioned_keys).to eq([ "F-999" ])
  end

  it "does not attribute to a discarded feature" do
    feature = create(:feature, team: team, status: "discarded")

    result = described_class.call(event_with(title: "F-#{feature.number}"))

    expect(result.feature).to be_nil
  end
end
