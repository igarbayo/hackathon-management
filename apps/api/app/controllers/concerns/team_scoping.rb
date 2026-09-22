# Todas las rutas de dominio bajo /teams/:team_id (RNF-SEC-001). Si el
# usuario o el token no son del equipo, responde 404 para no revelar que el
# equipo existe (03-api.md#convenciones-generales).
#
# Admite tanto sesión web como Bearer (PAT, token de miembro; OAuth e
# integración se añaden cuando existan, en Tokens::Resolve) para que la API
# de dominio sea "la misma API" con cualquiera de los dos (RF-API-004).
module TeamScoping
  extend ActiveSupport::Concern

  included do
    class_attribute :session_only_actions, default: []
    class_attribute :scope_requirements, default: []

    before_action :reject_mixed_credentials!
    before_action :authenticate_for_team_scope!
    before_action :enforce_session_only!
    before_action :load_team_and_membership
    before_action :enforce_required_scope!
  end

  class_methods do
    # Acciones que solo admiten sesión web, nunca Bearer
    # (03-api.md#qué-no-se-puede-hacer-con-un-token). Responden 403
    # session_required a cualquier token, sea cual sea su scope.
    def session_only(*actions)
      self.session_only_actions = session_only_actions + actions.map(&:to_sym)
    end

    # Acciones que, autenticadas por token, exigen ese scope
    # (12-acceso-programatico.md#scopes--rf-api-002-f2-aceptado). La sesión
    # web nunca necesita scope: tiene todo lo que permite el rol.
    def requires_scope(scope, only:)
      self.scope_requirements = scope_requirements + [{ scope: scope, actions: Array(only).map(&:to_sym) }]
    end
  end

  private

  def bearer_token
    header = request.headers["Authorization"]
    header&.start_with?("Bearer ") ? header.delete_prefix("Bearer ") : nil
  end

  def reject_mixed_credentials!
    return unless cookies[Authentication::SESSION_COOKIE].present? && bearer_token.present?

    raise ApiError::BadRequest.new(message: "no se puede autenticar con cookie de sesión y con Bearer a la vez")
  end

  def authenticate_for_team_scope!
    token = bearer_token
    return authenticate_user! if token.blank?

    @resolved_token = ::Tokens::Resolve.call(token)
    raise ApiError::Unauthenticated.new(message: "token inválido o revocado") unless @resolved_token

    enforce_token_rate_limit!
  end

  # RNF-API-001: 120 peticiones/min en total y 30 escrituras/min por token.
  def enforce_token_rate_limit!
    key = @resolved_token.token_record&.id || "member:#{@resolved_token.membership.id}"
    RateLimiter.check!("token:#{key}", limit: 120, period: 1.minute)
    RateLimiter.check!("token:#{key}:write", limit: 30, period: 1.minute) if request.method.in?(%w[POST PUT PATCH DELETE])
  end

  def enforce_session_only!
    return unless @resolved_token
    raise ApiError::SessionRequired.new if self.class.session_only_actions.include?(action_name.to_sym)
  end

  def enforce_required_scope!
    return unless @resolved_token

    self.class.scope_requirements.each do |req|
      next unless req[:actions].include?(action_name.to_sym)

      raise ApiError::InsufficientScope.new(req[:scope]) unless @resolved_token.scopes.include?(req[:scope])
    end
  end

  def load_team_and_membership
    if @resolved_token
      @team = @resolved_token.team
      @membership = @resolved_token.membership
      raise ApiError::NotFound.new(message: "equipo no encontrado") if @team.nil? || @membership.nil? || @team.id.to_s != team_id_param.to_s
    else
      @team = Team.active.where(id: team_id_param).first
      @membership = @team && Membership.where(team_id: @team.id, user_id: current_user.id).first
      raise ApiError::NotFound.new(message: "equipo no encontrado") unless @membership
    end
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

  def current_user
    return @membership&.user if @resolved_token

    super
  end

  # via de RF-API-006: nil si el cambio viene de la web con sesión.
  def current_via(client: nil)
    return nil unless @resolved_token

    @resolved_token.via(channel: "api", client: client)
  end

  def require_owner!
    raise ApiError::Forbidden.new(message: "hace falta ser owner del equipo") unless current_membership.owner?
  end
end
