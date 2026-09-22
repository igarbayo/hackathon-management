require "rails_helper"

RSpec.describe Github::RepoUrl do
  it "acepta org/repo" do
    expect(described_class.parse("org/repo")).to eq("org/repo")
  end

  it "acepta una URL completa" do
    expect(described_class.parse("https://github.com/org/repo")).to eq("org/repo")
  end

  it "quita el .git final" do
    expect(described_class.parse("https://github.com/org/repo.git")).to eq("org/repo")
  end

  it "devuelve nil si no reconoce el formato" do
    expect(described_class.parse("no es un repo")).to be_nil
  end
end
