# POST /cli/device (RF-CC-001): no auth. If team_code comes in, the team is
# resolved right away so the approval screen does not have to ask for it.
module Cli
  class CreateDeviceAuthorization
    Result = Struct.new(:device_code, :record, keyword_init: true)

    def self.call(team_code: nil)
      device_code = SecureRandom.hex(32)
      team = team_code.present? ? Team.active.where(code: team_code.to_s.upcase.delete("-")).first : nil

      record = DeviceAuthorization.create!(device_code_digest: Digest::SHA256.hexdigest(device_code), team: team)

      Result.new(device_code: device_code, record: record)
    end
  end
end
