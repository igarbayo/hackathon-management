require "rails_helper"

RSpec.describe Github::RepoUrl do
  it "accepts org/repo" do
    expect(described_class.parse("org/repo")).to eq("org/repo")
  end

  it "accepts a full URL" do
    expect(described_class.parse("https://github.com/org/repo")).to eq("org/repo")
  end

  it "removes the trailing .git" do
    expect(described_class.parse("https://github.com/org/repo.git")).to eq("org/repo")
  end

  it "returns nil if it does not recognize the format" do
    expect(described_class.parse("not a repo")).to be_nil
  end
end
