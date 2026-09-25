# Double-submit CSRF without the Rails session store
# (03-api.md#convenciones-generales). GET /api/v1/csrf sets an httpOnly seed
# (hb_csrf_seed) and returns a token derived from it. Requests that change state must
# repeat that token in the X-CSRF-Token header; the server works it out again from the
# cookie seed and compares them.
module Csrf
  SEED_COOKIE = :hb_csrf_seed

  module_function

  def token_for(seed)
    OpenSSL::HMAC.hexdigest("SHA256", secret, seed)
  end

  def valid?(seed, token)
    return false if seed.blank? || token.blank?

    ActiveSupport::SecurityUtils.secure_compare(token_for(seed), token)
  end

  def generate_seed
    SecureRandom.hex(32)
  end

  def secret
    Rails.application.secret_key_base
  end
end
