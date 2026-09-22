# Todo documento de dominio que no sea User, Session u OAuthClient lleva
# team_id (RNF-SEC-001, 02-modelo-datos.md#convenciones). Nunca se debe
# consultar uno de estos modelos sin acotar por equipo.
module TeamScoped
  extend ActiveSupport::Concern

  included do
    belongs_to :team

    index({ team_id: 1 })

    scope :for_team, ->(team) { where(team_id: team.id) }
  end
end
