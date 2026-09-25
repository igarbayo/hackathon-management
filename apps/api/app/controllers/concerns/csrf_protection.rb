module CsrfProtection
  extend ActiveSupport::Concern

  SAFE_METHODS = %w[GET HEAD OPTIONS].freeze

  def verify_csrf!
    return if SAFE_METHODS.include?(request.method)
    # RNF-SEC-003/RF-API-004: double-submit CSRF protects the session cookie. A
    # Bearer is not sent automatically like the cookie, so it is not a CSRF
    # vector and it is not required (TeamScoping already rejects requests that
    # send both).
    return if request.headers["Authorization"]&.start_with?("Bearer ")

    seed = cookies[Csrf::SEED_COOKIE]
    token = request.headers["X-CSRF-Token"]

    raise ApiError::Forbidden.new(message: "missing or invalid X-CSRF-Token") unless Csrf.valid?(seed, token)
  end
end
