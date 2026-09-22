# POST /teams/:team_id/cli/device/approve (RF-CC-002). La persona ya tiene
# sesión y es miembro del equipo (TeamScoping); aquí solo se resuelve el
# device_authorization pendiente contra ese team/membership.
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
      raise ApiError::NotFound.new(message: "código no encontrado") unless record
      raise ApiError::BadRequest.new(message: "este código ya no está disponible") unless record.status == "pending"
      raise ApiError::BadRequest.new(message: "este código ha caducado") if record.expired?

      if record.team_id.present? && record.team_id != team.id
        raise ApiError::Conflict.new(message: "este código es de otro equipo")
      end

      unless ClaudeCodeLink::PRIVACY_LEVELS.include?(privacy_level)
        raise ApiError::BadRequest.new(message: "nivel de privacidad no válido")
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
