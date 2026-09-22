# POST /teams/:team_id/tokens (RF-API-001). Un miembro solo crea PATs para
# sí mismo. El valor en claro solo se devuelve aquí, una vez (RNF-SEC-002).
module Pat
  Result = Struct.new(:raw_token, :record, keyword_init: true)

  PRESETS = {
    "observar" => %w[read],
    "agente" => %w[read features:write arguments:write progress:write],
    "completo" => %w[read features:write objectives:write arguments:write milestones:write attribution:write analyses:run progress:write]
  }.freeze

  class Create
    def self.call(membership:, name:, preset: nil, scopes: nil, expires_at: nil)
      resolved_scopes = (scopes.presence || PRESETS.fetch(preset.presence || "observar")) | ["read"]
      raw_token = "hb_pat_#{SecureRandom.hex(24)}"

      token = AccessToken.create!(
        kind: "pat",
        team_id: membership.team_id,
        membership_id: membership.id,
        user_id: membership.user_id,
        created_by_id: membership.user_id,
        name: name,
        scopes: resolved_scopes,
        token_digest: Digest::SHA256.hexdigest(raw_token),
        token_prefix: raw_token[0, 12],
        expires_at: expires_at || default_expiry(membership.team)
      )

      Result.new(raw_token: raw_token, record: token)
    end

    def self.default_expiry(team)
      ends_at = team.hackathon&.ends_at
      base = ends_at ? [ends_at + 7.days, Time.current].max : 30.days.from_now
      [base, AccessToken::MAX_LIFETIME.from_now].min
    end
  end
end
