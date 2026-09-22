# Errores de dominio que ApplicationController traduce al formato de
# 03-api.md#formato-de-error. Los controladores y servicios los lanzan;
# nunca construyen la respuesta HTTP a mano.
class ApiError < StandardError
  attr_reader :status, :code, :details

  def initialize(status:, code:, message:, details: nil)
    @status = status
    @code = code
    @details = details
    super(message)
  end

  class Unauthenticated < ApiError
    def initialize(message: "hace falta iniciar sesión o autenticar la petición")
      super(status: :unauthorized, code: "unauthenticated", message: message)
    end
  end

  class Forbidden < ApiError
    def initialize(message: "no tienes permiso para hacer esto")
      super(status: :forbidden, code: "forbidden", message: message)
    end
  end

  class InsufficientScope < ApiError
    def initialize(required_scope)
      super(
        status: :forbidden,
        code: "insufficient_scope",
        message: "al token le falta el scope #{required_scope}",
        details: { required_scope: required_scope }
      )
    end
  end

  class SessionRequired < ApiError
    def initialize(message: "este endpoint no admite tokens, hace falta sesión web")
      super(status: :forbidden, code: "session_required", message: message)
    end
  end

  class NotFound < ApiError
    def initialize(message: "no encontrado")
      super(status: :not_found, code: "not_found", message: message)
    end
  end

  class Conflict < ApiError
    def initialize(message: "conflicto", details: nil)
      super(status: :conflict, code: "conflict", message: message, details: details)
    end
  end

  class BadRequest < ApiError
    def initialize(message: "petición inválida", details: nil)
      super(status: :bad_request, code: "bad_request", message: message, details: details)
    end
  end

  class IdempotencyKeyReused < ApiError
    def initialize(message: "esta Idempotency-Key ya se usó con un cuerpo distinto")
      super(status: :unprocessable_content, code: "idempotency_key_reused", message: message)
    end
  end
end
