# Verifica X-Hub-Signature-256 con comparación en tiempo constante
# (RF-GH-006, RNF-SEC-006).
module Github
  module WebhookSignature
    def self.valid?(payload_body, signature_header)
      return false if signature_header.blank?

      expected = "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", ENV.fetch("GITHUB_WEBHOOK_SECRET"), payload_body)
      ActiveSupport::SecurityUtils.secure_compare(expected, signature_header)
    end
  end
end
