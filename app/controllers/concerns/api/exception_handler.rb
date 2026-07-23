module Api::ExceptionHandler
  extend ActiveSupport::Concern

  included do
    rescue_from StandardError, with: :render_500
    rescue_from ActiveRecord::RecordNotFound, with: :render_404
    rescue_from ActionController::ParameterMissing, with: :render_400
    rescue_from ActiveRecord::RecordNotUnique, with: :render_409
    rescue_from ActiveRecord::RecordInvalid, with: :render_409
    rescue_from TooManyRequestsError, with: :render_429
  end

  private

  def render_400(exception = nil, messages = nil)
    render_error(400, "Bad Request", exception&.message, *messages)
  end

  def render_500(exception = nil, messages = nil)
    Rails.logger.error(exception.full_message) if exception
    detail = Rails.env.production? ? nil : exception&.message
    render_error(500, "Internal Server Error", detail, *messages)
  end

  def render_404(exception = nil, messages = nil)
    render_error(404, "Record Not Found")
  end

  def render_409(exception = nil, messages = nil)
    render_error(409, "Conflict")
  end

  def render_429(exception = nil, messages = nil)
    render_error(429, "Too Many Requests", exception&.message,
                 reset_at: exception&.reset_at&.iso8601)
  end

  def render_error(code, message, *error_messages, **extra)
    res = {
      message: message,
      errors: error_messages.compact
    }.merge(extra.compact)

    render json: res, status: code
  end
end
