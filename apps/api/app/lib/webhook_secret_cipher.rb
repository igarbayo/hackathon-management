# Cifra los secretos de firma de OutboundWebhook con WEBHOOK_SECRETS_KEY
# (01-arquitectura.md#configuración-variables-de-entorno). Hace falta poder
# recuperar el secreto en claro para firmar cada entrega, así que se cifra
# en vez de guardar solo un hash. Usa AES-256-GCM directamente (en vez de
# ActiveSupport::MessageEncryptor) para no depender de su formato de mensaje.
module WebhookSecretCipher
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
    raw_key = ENV.fetch("WEBHOOK_SECRETS_KEY") do
      raise MissingKeyError, "Falta la variable de entorno WEBHOOK_SECRETS_KEY"
    end

    Digest::SHA256.digest(raw_key)
  end
end
