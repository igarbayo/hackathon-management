# POST /cli/device/token (RF-CC-001). Sigue la semántica de errores de
# RFC 8628 (authorization_pending / access_denied / expired_token /
# invalid_grant) porque es lo que hackboard (el CLI) espera parsear, a
# diferencia del resto de la API que usa el formato de ApiError.
module Cli
  class ExchangeDeviceToken
    Result = Struct.new(:outcome, :token, :team, :membership, keyword_init: true)

    def self.call(device_code:)
      new(device_code: device_code).call
    end

    def initialize(device_code:)
      @device_code = device_code
    end

    def call
      record = DeviceAuthorization.where(device_code_digest: digest).first
      return Result.new(outcome: :invalid_grant) unless record
      return Result.new(outcome: :invalid_grant) if record.consumed?
      return Result.new(outcome: :expired_token) if record.expired?
      return Result.new(outcome: :access_denied) if record.status == "denied"
      return Result.new(outcome: :authorization_pending) if record.status == "pending"

      mint!(record)
    end

    private

    attr_reader :device_code

    def digest
      Digest::SHA256.hexdigest(device_code.to_s)
    end

    def mint!(record)
      membership = record.membership
      raw_token = "hb_mt_#{SecureRandom.hex(24)}"

      membership.build_claude_code unless membership.claude_code
      membership.claude_code.assign_attributes(
        token_digest: Digest::SHA256.hexdigest(raw_token),
        token_prefix: raw_token[0, 12],
        privacy_level: record.privacy_level,
        connected_at: Time.current,
        last_event_at: nil,
        paused: false
      )
      membership.save!
      record.update!(consumed_at: Time.current)

      Result.new(outcome: :ok, token: raw_token, team: record.team, membership: membership)
    end
  end
end
