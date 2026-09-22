# state firmado del flujo de instalación/vinculación (RF-GH-020). Lleva
# team_id, user_id y, si el usuario pegó un repo antes de instalar, su
# full_name, para vincularlo solo al volver de la Setup URL.
module Github
  module InstallState
    TTL = 15.minutes

    def self.verifier
      Rails.application.message_verifier(:github_install_state)
    end

    def self.generate(team:, user:, pasted_full_name: nil)
      verifier.generate({ "team_id" => team.id.to_s, "user_id" => user.id.to_s, "pasted_full_name" => pasted_full_name }, expires_in: TTL)
    end

    def self.verify(state)
      verifier.verify(state)
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      raise ApiError::BadRequest.new(message: "state inválido o caducado")
    end
  end
end
