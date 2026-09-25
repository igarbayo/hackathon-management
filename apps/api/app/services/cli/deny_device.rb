# POST /teams/:team_id/cli/device/deny (RF-CC-002).
module Cli
  class DenyDevice
    def self.call(team:, user_code:)
      record = DeviceAuthorization.find_by_user_code(user_code)
      raise ApiError::NotFound.new(message: "code not found") unless record
      raise ApiError::BadRequest.new(message: "this code is no longer available") unless record.status == "pending"

      if record.team_id.present? && record.team_id != team.id
        raise ApiError::Conflict.new(message: "this code belongs to another team")
      end

      record.update!(status: "denied")
      record
    end
  end
end
