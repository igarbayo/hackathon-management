# Every domain document other than User, Session or OAuthClient has a team_id
# (RNF-SEC-001, 02-modelo-datos.md#convenciones). One of these models must never
# be queried without scoping it to a team.
module TeamScoped
  extend ActiveSupport::Concern

  included do
    belongs_to :team

    index({ team_id: 1 })

    scope :for_team, ->(team) { where(team_id: team.id) }
  end
end
