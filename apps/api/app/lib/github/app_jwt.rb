# JWT de la GitHub App (RS256), para autenticarse como la App y pedir
# installation access tokens (07-integracion-github.md).
module Github
  module AppJwt
    TTL = 9.minutes # GitHub exige <= 10 min

    def self.generate
      now = Time.now.to_i
      payload = { iat: now - 60, exp: now + TTL.to_i, iss: ENV.fetch("GITHUB_APP_ID") }

      JWT.encode(payload, private_key, "RS256")
    end

    def self.private_key
      OpenSSL::PKey::RSA.new(ENV.fetch("GITHUB_APP_PRIVATE_KEY"))
    end
  end
end
