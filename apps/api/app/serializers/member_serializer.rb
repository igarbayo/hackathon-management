class MemberSerializer
  def initialize(membership)
    @membership = membership
  end

  def as_json
    {
      id: membership.id.to_s,
      user_id: membership.user_id.to_s,
      role: membership.role,
      display_name: membership.display_name,
      git_identities: membership.git_identities,
      claude_code: claude_code_json
    }
  end

  private

  attr_reader :membership

  def claude_code_json
    link = membership.claude_code
    return nil unless link

    {
      connected: true,
      token_prefix: link.token_prefix,
      privacy_level: link.privacy_level,
      paused: link.paused,
      connected_at: link.connected_at&.iso8601,
      last_event_at: link.last_event_at&.iso8601
    }
  end
end
