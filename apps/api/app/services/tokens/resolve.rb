# Resuelve cualquier Bearer de la API de dominio (no la ingesta de Claude
# Code, que tiene su propio TokenAuthentication) a un miembro/equipo/scopes,
# sea cual sea su prefijo (12-acceso-programatico.md#tipos-de-token).
module Tokens
  Resolved = Struct.new(:kind, :team, :membership, :scopes, :token_record, :token_prefix, :client_name, keyword_init: true) do
    # client_name lo rellena Mcp::Dispatch a partir del initialize de esa
    # sesión (12-acceso-programatico.md#servidor-mcp); dato informativo, no
    # se usa nunca para autorizar.
    def via(channel:, client: nil)
      { "channel" => channel, "token_kind" => kind, "token_id" => token_record&.id&.to_s, "token_prefix" => token_prefix, "client" => client || client_name }
    end
  end

  class Resolve
    MEMBER_PREFIX = "hb_mt_"
    PAT_PREFIX = "hb_pat_"
    INTEGRATION_PREFIX = "hb_it_"
    OAUTH_PREFIX = "hb_oat_"

    # Scopes fijos del token de miembro (12-acceso-programatico.md#tipos-de-token):
    # CLI de hooks y MCP básico.
    MEMBER_SCOPES = %w[ingest read progress:write].freeze

    # expected_resource (RFC 8707, RNF-SEC-015): solo lo comprueban los
    # tokens OAuth, que están ligados a un recurso concreto. Los demás
    # prefijos ya sirven solo a su propio uso (CLI, PAT del equipo…).
    def self.call(raw_token, expected_resource: nil)
      return nil if raw_token.blank?

      resolved = resolve(raw_token, expected_resource)
      usable?(resolved) ? resolved : nil
    end

    # Aunque borrar un equipo o una membresía ya revoca sus tokens, un token
    # de un equipo borrado o de una persona que ya no es miembro nunca vale:
    # sin membresía, un PAT u OAuth actuaría como si fuera del equipo entero.
    def self.usable?(resolved)
      return false unless resolved&.team && !resolved.team.deleted?

      resolved.kind == "integration" || resolved.membership.present?
    end
    private_class_method :usable?

    def self.resolve(raw_token, expected_resource)
      if raw_token.start_with?(MEMBER_PREFIX)
        resolve_member(raw_token)
      elsif raw_token.start_with?(PAT_PREFIX)
        resolve_pat(raw_token)
      elsif raw_token.start_with?(INTEGRATION_PREFIX)
        resolve_integration(raw_token)
      elsif raw_token.start_with?(OAUTH_PREFIX)
        resolve_oauth(raw_token, expected_resource)
      end
    end
    private_class_method :resolve

    def self.resolve_member(raw_token)
      membership = Membership.where("claude_code.token_digest" => Digest::SHA256.hexdigest(raw_token)).first
      return nil unless membership && !membership.claude_code.paused

      Resolved.new(kind: "member", team: membership.team, membership: membership, scopes: MEMBER_SCOPES, token_prefix: membership.claude_code.token_prefix)
    end
    private_class_method :resolve_member

    def self.resolve_pat(raw_token)
      token = AccessToken.active.where(kind: "pat", token_digest: Digest::SHA256.hexdigest(raw_token)).first
      return nil unless token

      touch_last_used(token)
      Resolved.new(kind: "pat", team: token.team, membership: token.membership, scopes: token.scopes, token_record: token, token_prefix: token.token_prefix)
    end
    private_class_method :resolve_pat

    def self.resolve_integration(raw_token)
      token = AccessToken.active.where(kind: "integration", token_digest: Digest::SHA256.hexdigest(raw_token)).first
      return nil unless token

      touch_last_used(token)
      Resolved.new(kind: "integration", team: token.team, membership: nil, scopes: token.scopes, token_record: token, token_prefix: token.token_prefix)
    end
    private_class_method :resolve_integration

    def self.resolve_oauth(raw_token, expected_resource)
      token = AccessToken.active.where(kind: "oauth", token_digest: Digest::SHA256.hexdigest(raw_token)).first
      return nil unless token
      return nil if expected_resource && token.resource != expected_resource

      touch_last_used(token)
      Resolved.new(kind: "oauth", team: token.team, membership: token.membership, scopes: token.scopes, token_record: token, token_prefix: token.token_prefix)
    end
    private_class_method :resolve_oauth

    # Resolución de 1 min (RF-API-003): no escribe en cada petición.
    def self.touch_last_used(token)
      return if token.last_used_at && token.last_used_at > 1.minute.ago

      token.set(last_used_at: Time.current)
    end
    private_class_method :touch_last_used
  end
end
