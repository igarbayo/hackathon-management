require "rails_helper"

RSpec.describe GeminiApiKeyCipher do
  around do |example|
    original = ENV["GEMINI_API_KEY_ENCRYPTION_KEY"]
    ENV["GEMINI_API_KEY_ENCRYPTION_KEY"] = "test-encryption-key"
    example.run
    ENV["GEMINI_API_KEY_ENCRYPTION_KEY"] = original
  end

  it "encrypts and decrypts back to the original text" do
    encrypted = described_class.encrypt("fake-gemini-key")

    expect(encrypted).not_to include("fake-gemini-key")
    expect(described_class.decrypt(encrypted)).to eq("fake-gemini-key")
  end

  it "gives a different result on each encryption (random IV)" do
    a = described_class.encrypt("same-key")
    b = described_class.encrypt("same-key")

    expect(a).not_to eq(b)
    expect(described_class.decrypt(a)).to eq("same-key")
    expect(described_class.decrypt(b)).to eq("same-key")
  end

  it "raises MissingKeyError if GEMINI_API_KEY_ENCRYPTION_KEY is missing" do
    ENV["GEMINI_API_KEY_ENCRYPTION_KEY"] = nil

    expect { described_class.encrypt("x") }.to raise_error(GeminiApiKeyCipher::MissingKeyError)
  end
end
