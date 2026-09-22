# Servidor de autorización OAuth 2.1 (12-acceso-programatico.md#oauth-21,
# ADR-0011). Los scopes son los mismos que los de un PAT (02-modelo-datos.md#accesstoken).
module OAuth
  SCOPES = %w[
    read features:write objectives:write arguments:write milestones:write
    attribution:write analyses:run progress:write
  ].freeze

  ACCESS_TOKEN_TTL = 1.hour
  REFRESH_TOKEN_TTL = 30.days
  MAX_CONNECTION_LIFETIME = 90.days
end
