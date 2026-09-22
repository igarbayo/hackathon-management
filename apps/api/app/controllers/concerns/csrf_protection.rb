module CsrfProtection
  extend ActiveSupport::Concern

  SAFE_METHODS = %w[GET HEAD OPTIONS].freeze

  def verify_csrf!
    return if SAFE_METHODS.include?(request.method)
    # RNF-SEC-003/RF-API-004: el CSRF de doble envío protege la cookie de
    # sesión. Un Bearer no se manda solo con la cookie, así que no es un
    # vector CSRF y no lo exige (TeamScoping ya rechaza si vienen los dos).
    return if request.headers["Authorization"]&.start_with?("Bearer ")

    seed = cookies[Csrf::SEED_COOKIE]
    token = request.headers["X-CSRF-Token"]

    raise ApiError::Forbidden.new(message: "falta o no es válido X-CSRF-Token") unless Csrf.valid?(seed, token)
  end
end
