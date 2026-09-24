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

  describe "longitud máxima de la contraseña (límite de bcrypt)" do
    it "acepta 72 bytes" do
      expect(build(:user, password: "a" * 72)).to be_valid
    end

    it "rechaza más de 72 bytes" do
      user = build(:user, password: "a" * 73)

      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end

    it "cuenta bytes, no caracteres" do
      user = build(:user, password: "ñ" * 37)

      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end
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

  describe "#gemini_api_key" do
    it "se guarda cifrada y se descifra de vuelta al leerla" do
      user = create(:user)

      user.gemini_api_key = "fake-gemini-key"
      user.save!
      user.reload

      expect(user.gemini_api_key_encrypted).not_to include("fake-gemini-key")
      expect(user.gemini_api_key).to eq("fake-gemini-key")
      expect(user.gemini_api_key_configured?).to be true
    end

    it "sin clave, no está configurada" do
      user = create(:user)

      expect(user.gemini_api_key).to be_nil
      expect(user.gemini_api_key_configured?).to be false
    end

    it "se puede quitar asignando un valor en blanco" do
      user = create(:user)
      user.update!(gemini_api_key: "fake-gemini-key")

      user.update!(gemini_api_key: "")

      expect(user.reload.gemini_api_key_configured?).to be false
    end
  end

  describe "#remember_last_team!" do
    it "guarda el equipo como el último abierto" do
      user = create(:user)
      team = create(:team)

      user.remember_last_team!(team.id)

      expect(user.reload.last_team_id).to eq(team.id)
    end

    it "no escribe si ya era ese equipo" do
      team = create(:team)
      user = create(:user, last_team_id: team.id)

      expect(user).not_to receive(:set)
      user.remember_last_team!(team.id)
    end
  end
end
