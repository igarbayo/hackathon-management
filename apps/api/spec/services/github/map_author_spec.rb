require "rails_helper"

RSpec.describe Github::MapAuthor do
  let(:team) { create(:team) }

  it "mapea por github_login" do
    user = create(:user, github_login: "adalovelace")
    membership = create(:membership, team: team, user: user)

    result = described_class.call(team: team, login: "adalovelace", email: nil, display_name: "Ada")

    expect(result["user_id"]).to eq(membership.user_id.to_s)
  end

  it "mapea por email si no hay login" do
    user = create(:user, email: "ada@example.com")
    membership = create(:membership, team: team, user: user)

    result = described_class.call(team: team, login: nil, email: "ADA@example.com", display_name: nil)

    expect(result["user_id"]).to eq(membership.user_id.to_s)
  end

  it "mapea por git_identities si el email no coincide con el de la cuenta" do
    membership = create(:membership, team: team, git_identities: [ "ada@work.example.com" ])

    result = described_class.call(team: team, login: nil, email: "ada@work.example.com", display_name: nil)

    expect(result["user_id"]).to eq(membership.user_id.to_s)
  end

  it "extrae el login de un email noreply de GitHub y lo mapea" do
    user = create(:user, github_login: "adalovelace")
    membership = create(:membership, team: team, user: user)

    result = described_class.call(team: team, login: nil, email: "12345+adalovelace@users.noreply.github.com", display_name: nil)

    expect(result["user_id"]).to eq(membership.user_id.to_s)
  end

  it "sin coincidencia, deja user_id a nil y usa el nombre para mostrar" do
    result = described_class.call(team: team, login: "desconocido", email: "x@example.com", display_name: "Desconocido")

    expect(result["user_id"]).to be_nil
    expect(result["display"]).to eq("Desconocido")
    expect(result["github_login"]).to eq("desconocido")
  end

  it "guarda siempre la identidad del autor, sea o no miembro (ADR-0018)" do
    result = described_class.call(team: team, login: "Grace", email: "Grace@Example.com", display_name: "Grace Hopper")

    expect(result).to include("github_login" => "Grace", "email" => "grace@example.com", "author_name" => "Grace Hopper")
    expect(result["mapped_by"]).to be_nil
  end

  it "compara el login sin distinguir mayúsculas y marca mapped_by auto" do
    user = create(:user, github_login: "AdaLovelace")
    membership = create(:membership, team: team, user: user)

    result = described_class.call(team: team, login: "adalovelace", email: nil, display_name: nil)

    expect(result["membership_id"]).to eq(membership.id.to_s)
    expect(result["mapped_by"]).to eq("auto")
  end

  it "mapea por un login guardado en git_identities" do
    membership = create(:membership, team: team, git_identities: [ "ada-alt" ])

    result = described_class.call(team: team, login: "Ada-Alt", email: nil, display_name: nil)

    expect(result["membership_id"]).to eq(membership.id.to_s)
  end
end
