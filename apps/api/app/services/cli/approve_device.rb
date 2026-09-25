# POST /teams/:team_id/cli/device/approve (RF-CC-002). The person already has a
# session and is a team member (TeamScoping); here the pending
# device_authorization is only resolved against that team/membership.
module Cli
  class ApproveDevice
    def self.call(team:, membership:, user_code:, privacy_level:)
      new(team: team, membership: membership, user_code: user_code, privacy_level: privacy_level).call
    end

    def initialize(team:, membership:, user_code:, privacy_level:)
      @team = team
      @membership = membership
      @user_code = user_code
      @privacy_level = privacy_level
    end

    def call
      record = DeviceAuthorization.find_by_user_code(user_code)
      raise ApiError::NotFound.new(message: "code not found") unless record
      raise ApiError::BadRequest.new(message: "this code is no longer available") unless record.status == "pending"
      raise ApiError::BadRequest.new(message: "this code has expired") if record.expired?

      if record.team_id.present? && record.team_id != team.id
        raise ApiError::Conflict.new(message: "this code belongs to another team")
      end

      unless ClaudeCodeLink::PRIVACY_LEVELS.include?(privacy_level)
        raise ApiError::BadRequest.new(message: "invalid privacy level")
      end

      record.update!(
        team: team,
        membership: membership,
        privacy_level: privacy_level,
        status: "approved"
      )

      record
    end

    private

    attr_reader :team, :membership, :user_code, :privacy_level
  end
end
