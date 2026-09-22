module CsrfProtection
  extend ActiveSupport::Concern

  SAFE_METHODS = %w[GET HEAD OPTIONS].freeze

  def verify_csrf!
    return if SAFE_METHODS.include?(request.method)

    seed = cookies[Csrf::SEED_COOKIE]
    token = request.headers["X-CSRF-Token"]

    raise ApiError::Forbidden.new(message: "falta o no es válido X-CSRF-Token") unless Csrf.valid?(seed, token)
  end
end
