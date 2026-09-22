require "rails_helper"

RSpec.describe User, type: :model do
  it "requiere email y nombre" do
    user = User.new

    expect(user).not_to be_valid
    expect(user.errors[:email]).to be_present
    expect(user.errors[:name]).to be_present
  end

  it "guarda el email en minúsculas" do
    user = create(:user, email: "ADA@Example.com")
    expect(user.email).to eq("ada@example.com")
  end

  it "no permite emails repetidos" do
    create(:user, email: "dup@example.com")
    duplicate = build(:user, email: "dup@example.com")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:email]).to be_present
  end

  it "exige contraseña, GitHub o Google para poder autenticar" do
    user = build(:user, password: nil, github_uid: nil, google_sub: nil)

    expect(user).not_to be_valid
    expect(user.errors[:base]).to be_present
  end

  it "es válido solo con github_uid, sin contraseña" do
    user = build(:user, password: nil, github_uid: 12_345)

    expect(user).to be_valid
  end

  it "permite muchos usuarios sin github_uid (índice disperso)" do
    create(:user, github_uid: nil)
    other = build(:user, github_uid: nil)

    expect(other).to be_valid
  end

  it "no permite dos usuarios con el mismo github_uid" do
    create(:user, github_uid: 42)
    duplicate = build(:user, github_uid: 42)

    expect(duplicate).not_to be_valid
  end
end
