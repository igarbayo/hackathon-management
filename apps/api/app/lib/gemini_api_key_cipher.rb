# Encrypts the Gemini key each user stores in their profile
# (06-analisis-ia.md#proveedor, RF-AI-021) with GEMINI_API_KEY_ENCRYPTION_KEY.
# Same scheme as WebhookSecretCipher (AES-256-GCM directly, without depending on
# ActiveSupport::MessageEncryptor's message format), but with its own encryption
# key so two unrelated secrets are not coupled.
module GeminiApiKeyCipher
  class MissingKeyError < StandardError; end

  CIPHER = "aes-256-gcm"

  module_function

  def encrypt(plaintext)
    cipher = OpenSSL::Cipher.new(CIPHER)
    cipher.encrypt
    cipher.key = key
    iv = cipher.random_iv
    cipher.auth_data = ""

    ciphertext = cipher.update(plaintext) + cipher.final
    auth_tag = cipher.auth_tag

    [ iv, auth_tag, ciphertext ].map { |part| Base64.strict_encode64(part) }.join("|")
  end

  def decrypt(encoded)
    iv, auth_tag, ciphertext = encoded.split("|", 3).map { |part| Base64.strict_decode64(part) }

    cipher = OpenSSL::Cipher.new(CIPHER)
    cipher.decrypt
    cipher.key = key
    cipher.iv = iv
    cipher.auth_tag = auth_tag
    cipher.auth_data = ""

    cipher.update(ciphertext) + cipher.final
  end

  def key
    raw_key = ENV.fetch("GEMINI_API_KEY_ENCRYPTION_KEY") do
      raise MissingKeyError, "Missing environment variable GEMINI_API_KEY_ENCRYPTION_KEY"
    end

    Digest::SHA256.digest(raw_key)
  end
end
