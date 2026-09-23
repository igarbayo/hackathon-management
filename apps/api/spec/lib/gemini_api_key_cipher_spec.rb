require "rails_helper"

RSpec.describe GeminiApiKeyCipher do
  around do |example|
    original = ENV["GEMINI_API_KEY_ENCRYPTION_KEY"]
    ENV["GEMINI_API_KEY_ENCRYPTION_KEY"] = "test-encryption-key"
    example.run
    ENV["GEMINI_API_KEY_ENCRYPTION_KEY"] = original
  end

  it "cifra y descifra de vuelta al texto original" do
    encrypted = described_class.encrypt("fake-gemini-key")

    expect(encrypted).not_to include("fake-gemini-key")
    expect(described_class.decrypt(encrypted)).to eq("fake-gemini-key")
  end

  it "da un resultado distinto en cada cifrado (IV aleatorio)" do
    a = described_class.encrypt("misma-clave")
    b = described_class.encrypt("misma-clave")

    expect(a).not_to eq(b)
    expect(described_class.decrypt(a)).to eq("misma-clave")
    expect(described_class.decrypt(b)).to eq("misma-clave")
  end

  it "lanza MissingKeyError si falta GEMINI_API_KEY_ENCRYPTION_KEY" do
    ENV["GEMINI_API_KEY_ENCRYPTION_KEY"] = nil

    expect { described_class.encrypt("x") }.to raise_error(GeminiApiKeyCipher::MissingKeyError)
  end
end
