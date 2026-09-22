# CSRF de doble envío sin el session store de Rails (03-api.md#convenciones-generales).
# GET /api/v1/csrf planta una semilla httpOnly (hb_csrf_seed) y devuelve un token
# derivado de ella. Las peticiones que cambian estado tienen que repetir ese token
# en la cabecera X-CSRF-Token; el servidor lo recalcula a partir de la semilla de
# la cookie y lo compara.
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
