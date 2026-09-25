# Signed state of the install/link flow (RF-GH-020). It carries team_id, user_id
# and, if the user pasted a repo before installing, its full_name, so it is
# linked only when coming back from the Setup URL. `return_to` says which
# screen to go back to: settings by default, or "onboarding" (RF-TEAM-014).
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
      raise ApiError::BadRequest.new(message: "invalid or expired state")
    end
  end
end
