class ApplicationController < ActionController::API
  include ActionController::Cookies
  include Authentication
  include CsrfProtection

  rescue_from ApiError, with: :render_api_error
  rescue_from RateLimiter::LimitExceeded, with: :render_rate_limited
  rescue_from Mongoid::Errors::DocumentNotFound, with: :render_not_found
  rescue_from Mongoid::Errors::Validations, with: :render_validation_failed

  private

  def render_api_error(error)
    render_error(error.status, error.code, error.message, details: error.details)
  end

  def render_rate_limited(error)
    response.headers["Retry-After"] = error.retry_after.to_s
    render_error(:too_many_requests, "rate_limited", "too many requests, try again later")
  end

  def render_not_found(_error)
    render_error(:not_found, "not_found", "not found")
  end

  def render_validation_failed(error)
    render_validation_errors(error.document)
  end

  def render_validation_errors(record)
    render_error(
      :unprocessable_content,
      "validation_failed",
      record.errors.full_messages.first || "is not valid",
      details: record.errors.to_hash(full_messages: false)
    )
  end

  def render_error(status, code, message, details: nil)
    body = { error: { code: code, message: message } }
    body[:error][:details] = details if details.present?
    render json: body, status: status
  end
end
