# POST /teams/:team_id/integrations (RF-API-011). Solo lo crea un owner. El
# actor es la integración, no una persona: sin membership.
module Integration
  class Create
    def self.call(team:, created_by:, name:, scopes:)
      raw_token = "hb_it_#{SecureRandom.hex(24)}"

      token = AccessToken.create!(
        kind: "integration",
        team_id: team.id,
        created_by_id: created_by.id,
        name: name,
        scopes: Array(scopes) | [ "read" ],
        token_digest: Digest::SHA256.hexdigest(raw_token),
        token_prefix: raw_token[0, 12],
        expires_at: default_expiry(team)
      )

      Tokens::MintResult.new(raw_token: raw_token, record: token)
    end

    def self.default_expiry(team)
      ends_at = team.hackathon&.ends_at
      base = ends_at ? [ ends_at + 7.days, Time.current ].max : 30.days.from_now
      [ base, AccessToken::MAX_LIFETIME.from_now ].min
    end
  end

  # RF-API-023: "rotar" un token de integración cambia el secreto sin tocar
  # nombre/scopes/histórico de uso, para automatizaciones que no quieren
  # reconfigurar todo tras una fuga de credenciales.
  class Rotate
    def self.call(token:)
      raw_token = "hb_it_#{SecureRandom.hex(24)}"
      token.update!(token_digest: Digest::SHA256.hexdigest(raw_token), token_prefix: raw_token[0, 12])
      Tokens::MintResult.new(raw_token: raw_token, record: token)
    end
  end
end
