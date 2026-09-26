# Who made a change, as it is stored in ActivityEvent#actor (02-modelo-datos.md).
# A person (web session or personal token) is their membership; an integration
# token is the integration itself, not a person
# (12-acceso-programatico.md#tokens-de-integración-de-equipo).
module Tracking
  module Actor
    def self.for(membership:, resolved_token: nil)
      if membership
        { "user_id" => membership.user_id.to_s, "membership_id" => membership.id.to_s, "display" => membership.display_name }
      elsif resolved_token
        token = resolved_token.token_record
        { "user_id" => nil, "membership_id" => nil, "integration_id" => token.id.to_s, "display" => "#{token.name} (integration)" }
      else
        {}
      end
    end
  end
end
