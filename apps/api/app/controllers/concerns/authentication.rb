# Sesión web con cookie opaca (ADR-0008). Los canales con Bearer token
# (PAT, OAuth, integración, token de miembro) se añaden en specs/12 y 08
# sin tocar esta autenticación de sesión.
module Authentication
  extend ActiveSupport::Concern

  SESSION_COOKIE = :hb_session
  SESSION_TOKEN_PREFIX = "hb_s_" # RNF-SEC-002: prefijo distintivo para escaneo de secretos

  included do
    helper_method :current_user, :current_session if respond_to?(:helper_method)
  end

  def current_session
    return @current_session if defined?(@current_session)

    token = cookies[SESSION_COOKIE]
    @current_session = nil
    return @current_session if token.blank?

    session = Session.where(token_digest: digest(token)).first
    @current_session = session if session && !session.expired?
  end

  def current_user
    @current_user ||= current_session&.user
  end

  def authenticate_user!
    raise ApiError::Unauthenticated unless current_user
  end

  def start_session!(user, request:)
    raw_token = "#{SESSION_TOKEN_PREFIX}#{SecureRandom.hex(32)}"
    session = Session.create!(
      user: user,
      token_digest: digest(raw_token),
      expires_at: Session::SLIDING_TTL.from_now,
      user_agent: request.user_agent,
      ip: request.remote_ip
    )
    cookies[SESSION_COOKIE] = {
      value: raw_token,
      httponly: true,
      secure: Rails.env.production?,
      same_site: :lax,
      expires: session.expires_at
    }
    session
  end

  def end_session!
    current_session&.destroy
    cookies.delete(SESSION_COOKIE)
    @current_session = nil
    @current_user = nil
  end

  private

  def digest(raw_token)
    Digest::SHA256.hexdigest(raw_token)
  end
end
