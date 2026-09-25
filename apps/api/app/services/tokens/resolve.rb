# Resolves any Bearer of the domain API (not the Claude Code ingest, which has
# its own TokenAuthentication) to a member/team/scopes, whatever its prefix
# (12-acceso-programatico.md#tipos-de-token).
module Tokens
  Resolved = Struct.new(:kind, :team, :membership, :scopes, :token_record, :token_prefix, :client_name, keyword_init: true) do
    # Mcp::Dispatch fills in client_name from that session's initialize
    # (12-acceso-programatico.md#servidor-mcp); informational data, never used
    # to authorize.
    def via(channel:, client: nil)
      { "channel" => channel, "token_kind" => kind, "token_id" => token_record&.id&.to_s, "token_prefix" => token_prefix, "client" => client || client_name }
    end
  end

  class Resolve
    MEMBER_PREFIX = "hb_mt_"
    PAT_PREFIX = "hb_pat_"
    INTEGRATION_PREFIX = "hb_it_"
    OAUTH_PREFIX = "hb_oat_"

    # Fixed scopes of the member token (12-acceso-programatico.md#tipos-de-token):
    # hooks CLI and basic MCP.
    MEMBER_SCOPES = %w[ingest read progress:write].freeze

    # expected_resource (RFC 8707, RNF-SEC-015): only OAuth tokens check it,
    # since they are tied to a specific resource. The other prefixes already
    # serve only their own use (CLI, team PAT…).
    def self.call(raw_token, expected_resource: nil)
      return nil if raw_token.blank?

      resolved = resolve(raw_token, expected_resource)
      usable?(resolved) ? resolved : nil
    end

    # Even though deleting a team or a membership already revokes its tokens, a
    # token from a deleted team or from someone who is no longer a member is
    # never valid: with no membership, a PAT or OAuth token would act as if it
    # were the whole team.
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

    # 1 min resolution (RF-API-003): it does not write on every request.
    def self.touch_last_used(token)
      return if token.last_used_at && token.last_used_at > 1.minute.ago

      token.set(last_used_at: Time.current)
    end
    private_class_method :touch_last_used
  end
end
