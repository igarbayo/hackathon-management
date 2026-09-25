# Domain errors that ApplicationController turns into the
# 03-api.md#formato-de-error format. Controllers and services raise them; they
# never build the HTTP response by hand.
class ApiError < StandardError
  attr_reader :status, :code, :details

  def initialize(status:, code:, message:, details: nil)
    @status = status
    @code = code
    @details = details
    super(message)
  end

  class Unauthenticated < ApiError
    def initialize(message: "you have to log in or authenticate the request")
      super(status: :unauthorized, code: "unauthenticated", message: message)
    end
  end

  class Forbidden < ApiError
    def initialize(message: "you do not have permission to do this")
      super(status: :forbidden, code: "forbidden", message: message)
    end
  end

  class InsufficientScope < ApiError
    def initialize(required_scope)
      super(
        status: :forbidden,
        code: "insufficient_scope",
        message: "the token is missing the #{required_scope} scope",
        details: { required_scope: required_scope }
      )
    end
  end

  class SessionRequired < ApiError
    def initialize(message: "this endpoint does not accept tokens, a web session is required")
      super(status: :forbidden, code: "session_required", message: message)
    end
  end

  class NotFound < ApiError
    def initialize(message: "not found")
      super(status: :not_found, code: "not_found", message: message)
    end
  end

  class Conflict < ApiError
    def initialize(message: "conflict", details: nil)
      super(status: :conflict, code: "conflict", message: message, details: details)
    end
  end

  class BadRequest < ApiError
    def initialize(message: "invalid request", details: nil)
      super(status: :bad_request, code: "bad_request", message: message, details: details)
    end
  end

  class IdempotencyKeyReused < ApiError
    def initialize(message: "this Idempotency-Key was already used with a different body")
      super(status: :unprocessable_content, code: "idempotency_key_reused", message: message)
    end
  end
end
