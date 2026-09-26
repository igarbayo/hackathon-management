# All domain routes under /teams/:team_id (RNF-SEC-001). If the user or the
# token do not belong to the team, it returns 404 so it does not reveal that the
# team exists (03-api.md#convenciones-generales).
#
# It accepts both a web session and a Bearer (PAT, member token; OAuth and
# integration are added when they exist, in Tokens::Resolve) so the domain API
# is "the same API" with either (RF-API-004).
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
    # Actions that only accept a web session, never a Bearer
    # (03-api.md#qué-no-se-puede-hacer-con-un-token). They return 403
    # session_required to any token, whatever its scope.
    def session_only(*actions)
      self.session_only_actions = session_only_actions + actions.map(&:to_sym)
    end

    # Actions that, when authenticated with a token, require that scope
    # (12-acceso-programatico.md#scopes--rf-api-002-f2-aceptado). The web
    # session never needs a scope: it has everything the role allows.
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

    raise ApiError::BadRequest.new(message: "cannot authenticate with a session cookie and Bearer at the same time")
  end

  def authenticate_for_team_scope!
    token = bearer_token
    return authenticate_user! if token.blank?

    @resolved_token = ::Tokens::Resolve.call(token, expected_resource: "#{ENV.fetch('API_URL', '')}/api/v1")
    raise ApiError::Unauthenticated.new(message: "invalid or revoked token") unless @resolved_token

    enforce_token_rate_limit!
  end

  # RNF-API-001: 120 requests/min in total and 30 writes/min per token.
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
      # An integration token has no membership of its own: it acts as the team, not as a person
      # (12-acceso-programatico.md#tokens-de-integración-de-equipo).
      membership_required = @resolved_token.kind != "integration"
      raise ApiError::NotFound.new(message: "team not found") if @team.nil? || (membership_required && @membership.nil?) || @team.id.to_s != team_id_param.to_s
    else
      @team = Team.active.where(id: team_id_param).first
      @membership = @team && Membership.where(team_id: @team.id, user_id: current_user.id).first
      raise ApiError::NotFound.new(message: "team not found") unless @membership

      # RF-TEAM-013: web session only, not Bearer (a CLI/integration token
      # acting on a team does not mean the person is looking at it).
      current_user.remember_last_team!(@team.id)
    end
  end

  # TeamsController uses /teams/:id for its own actions; the other controllers
  # hang from /teams/:team_id/... . It can be overridden.
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

  # via from RF-API-006: nil if the change comes from the web app with a
  # session.
  # Who is making this request, for the events it creates (Tracking::Actor).
  def current_actor
    Tracking::Actor.for(membership: current_membership, resolved_token: @resolved_token)
  end

  def current_via(client: nil)
    return nil unless @resolved_token

    @resolved_token.via(channel: "api", client: client)
  end

  # RF-API-005: Idempotency-Key on POST. The response is kept for 24 h per
  # (identity, key); repeating it with the same body returns it as is with
  # Idempotent-Replayed, and with another body it returns 422.
  IDEMPOTENCY_TTL = 24.hours

  def idempotency_key
    request.headers["Idempotency-Key"]
  end

  def check_idempotency_cache!
    return unless request.post? && idempotency_key.present?
    raise ApiError::BadRequest.new(message: "Idempotency-Key must be between 1 and 64 characters") if idempotency_key.length > 64

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
    raise ApiError::Forbidden.new(message: "you have to be a team owner") unless current_membership.owner?
  end

  # RF-API-006: if a write made with a token does not already create its own
  # event (feature_status_changed, feature_assigned…), it is recorded with
  # system/api_change. Writes made from the web app have no via, so they create
  # nothing here. Shared with the MCP server in Tracking::RecordApiChange,
  # because a token also writes from there.
  def record_api_change!(entity:, key:, fields:)
    return unless @resolved_token

    Tracking::RecordApiChange.call(
      team: current_team, membership: current_membership, resolved_token: @resolved_token,
      entity: entity, key: key, fields: fields, channel: "api"
    )
  end
end
