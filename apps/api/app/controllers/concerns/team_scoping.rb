# Todas las rutas de dominio bajo /teams/:team_id (RNF-SEC-001). Si el
# usuario no es miembro del equipo, responde 404 para no revelar que el
# equipo existe (03-api.md#convenciones-generales).
module TeamScoping
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
    before_action :load_team_and_membership
  end

  private

  def load_team_and_membership
    @team = Team.active.where(id: team_id_param).first
    @membership = @team && Membership.where(team_id: @team.id, user_id: current_user.id).first

    raise ApiError::NotFound.new(message: "equipo no encontrado") unless @membership
  end

  # TeamsController usa /teams/:id para sus propias acciones; el resto de
  # controladores cuelgan de /teams/:team_id/... . Se puede sobrescribir.
  def team_id_param
    params[:team_id] || params[:id]
  end

  def current_team
    @team
  end

  def current_membership
    @membership
  end

  def require_owner!
    raise ApiError::Forbidden.new(message: "hace falta ser owner del equipo") unless current_membership.owner?
  end
end
