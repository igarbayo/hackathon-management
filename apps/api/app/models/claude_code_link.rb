class ClaudeCodeLink
  include Mongoid::Document

  PRIVACY_LEVELS = %w[metadata summaries off].freeze

  embedded_in :membership

  field :token_digest, type: String
  field :token_prefix, type: String
  field :privacy_level, type: String, default: "metadata"
  field :connected_at, type: Time
  field :last_event_at, type: Time
  field :paused, type: Mongoid::Boolean, default: false
  field :cli_version, type: String

  validates :token_digest, presence: true
  validates :token_prefix, presence: true
  validates :privacy_level, inclusion: { in: PRIVACY_LEVELS }
end
