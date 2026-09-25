# Works out whose Gemini key is used for each AI call
# (06-analisis-ia.md#proveedor, RF-AI-021). Actions a person triggers (manual
# analysis, MCP) use their own key; automatic work (the scheduled analysis cron
# and the attribution suggestion) has no actor, so it uses the team owner's. If
# nobody has set one, the call is not made: there is no shared server key to
# fall back on.
module Ai
  module KeyOwner
    module_function

    def for(team)
      Membership.owners.where(team_id: team.id).first&.user
    end
  end
end
