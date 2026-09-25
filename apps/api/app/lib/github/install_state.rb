# Signed state of the install/link flow (RF-GH-020). It carries team_id, user_id
# and, if the user pasted a repo before installing, its full_name, so it is
# linked only when coming back from the Setup URL.
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
      raise ApiError::BadRequest.new(message: "invalid or expired state")
    end
  end
end
