# X-Hackboard-Signature-256: sha256=HMAC(secret, timestamp + "." + body)
# (12-acceso-programatico.md#webhooks-salientes).
module Webhooks
  module Sign
    module_function

    def signature(secret:, timestamp:, body:)
      "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', secret, "#{timestamp}.#{body}")}"
    end
  end
end
