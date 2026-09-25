# GitHub App JWT (RS256), to authenticate as the App and ask for installation
# access tokens (07-integracion-github.md).
module Github
  module AppJwt
    TTL = 9.minutes # GitHub requires <= 10 min

    def self.generate
      now = Time.now.to_i
      payload = { iat: now - 60, exp: now + TTL.to_i, iss: ENV.fetch("GITHUB_APP_ID") }

      JWT.encode(payload, private_key, "RS256")
    end

    def self.private_key
      # Docker Compose does not support multiline values in env_file, so in
      # production the key travels on a single line with literal \n.
      OpenSSL::PKey::RSA.new(ENV.fetch("GITHUB_APP_PRIVATE_KEY").gsub('\n', "\n"))
    end
  end
end
