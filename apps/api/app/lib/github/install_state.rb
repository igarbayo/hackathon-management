# state firmado del flujo de instalación/vinculación (RF-GH-020). Lleva
# team_id, user_id y, si el usuario pegó un repo antes de instalar, su
# full_name, para vincularlo solo al volver de la Setup URL. `return_to`
# dice a qué pantalla volver: ajustes por defecto u "onboarding" (RF-TEAM-014).
module Github
  module InstallState
    TTL = 15.minutes

    def self.verifier
      Rails.application.message_verifier(:github_install_state)
    end

    RETURN_TO = %w[settings onboarding].freeze

    def self.generate(team:, user:, pasted_full_name: nil, return_to: nil)
      return_to = RETURN_TO.include?(return_to) ? return_to : "settings"
      verifier.generate(
        { "team_id" => team.id.to_s, "user_id" => user.id.to_s, "pasted_full_name" => pasted_full_name, "return_to" => return_to },
        expires_in: TTL
      )
    end

    def self.verify(state)
      verifier.verify(state)
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      raise ApiError::BadRequest.new(message: "state inválido o caducado")
    end
  end
end
