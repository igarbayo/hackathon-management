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
    before_action :check_idempotency_cache!
    after_action :store_idempotency_response!
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
      self.scope_requirements = scope_requirements + [ { scope: scope, actions: Array(only).map(&:to_sym) } ]
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

    @resolved_token = ::Tokens::Resolve.call(token, expected_resource: "#{ENV.fetch('API_URL', '')}/api/v1")
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
      # Un token de integración no tiene membership propia: actúa como el
      # equipo, no como una persona (12-acceso-programatico.md#tokens-de-integración-de-equipo).
      membership_required = @resolved_token.kind != "integration"
      raise ApiError::NotFound.new(message: "equipo no encontrado") if @team.nil? || (membership_required && @membership.nil?) || @team.id.to_s != team_id_param.to_s
    else
      @team = Team.active.where(id: team_id_param).first
      @membership = @team && Membership.where(team_id: @team.id, user_id: current_user.id).first
      raise ApiError::NotFound.new(message: "equipo no encontrado") unless @membership

      # RF-TEAM-013: solo sesión web, no Bearer (un token de CLI/integración
      # actuando sobre un equipo no significa que la persona lo esté viendo).
      current_user.remember_last_team!(@team.id)
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

  # RF-API-005: Idempotency-Key en POST. Se guarda la respuesta 24 h por
  # (identidad, clave); repetirla con el mismo cuerpo la devuelve tal cual
  # con Idempotent-Replayed, y con otro cuerpo da 422.
  IDEMPOTENCY_TTL = 24.hours

  def idempotency_key
    request.headers["Idempotency-Key"]
  end

  def check_idempotency_cache!
    return unless request.post? && idempotency_key.present?
    raise ApiError::BadRequest.new(message: "Idempotency-Key tiene que tener entre 1 y 64 caracteres") if idempotency_key.length > 64

    cached = Sidekiq.redis { |conn| conn.call("GET", idempotency_redis_key) }
    return unless cached

    payload = JSON.parse(cached)
    raise ApiError::IdempotencyKeyReused.new if payload["body_hash"] != idempotency_body_hash

    response.headers["Idempotent-Replayed"] = "true"
    render json: JSON.parse(payload["body"]), status: payload["status"]
  end

  def store_idempotency_response!
    return unless request.post? && idempotency_key.present?
    return unless response.status.between?(200, 299)

    value = { body_hash: idempotency_body_hash, body: response.body, status: response.status }.to_json
    Sidekiq.redis { |conn| conn.call("SET", idempotency_redis_key, value, "EX", IDEMPOTENCY_TTL.to_i) }
  end

  def idempotency_identity
    @resolved_token&.token_record&.id || @resolved_token&.membership&.id || current_user&.id
  end

  def idempotency_redis_key
    "idempotency:#{idempotency_identity}:#{idempotency_key}"
  end

  def idempotency_body_hash
    Digest::SHA256.hexdigest(params.except(:controller, :action).to_unsafe_h.sort.to_h.to_json)
  end

  def require_owner!
    raise ApiError::Forbidden.new(message: "hace falta ser owner del equipo") unless current_membership.owner?
  end

  # RF-API-006: si una escritura hecha con un token no genera ya su propio
  # evento (feature_status_changed, feature_assigned…), se deja constancia
  # con system/api_change. Las escrituras hechas desde la web no llevan
  # via, así que no crean nada aquí. Compartido con el servidor MCP en
  # Tracking::RecordApiChange, porque un token también escribe desde ahí.
  def record_api_change!(entity:, key:, fields:)
    return unless @resolved_token

    Tracking::RecordApiChange.call(
      team: current_team, membership: current_membership, resolved_token: @resolved_token,
      entity: entity, key: key, fields: fields, channel: "api"
    )
  end
end
