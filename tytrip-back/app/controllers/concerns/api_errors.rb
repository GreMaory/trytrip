# Uniform JSON errors: { "error": { "code": "...", "message": "...", "details": {...} } }
module ApiErrors
  extend ActiveSupport::Concern

  class Unauthenticated < StandardError; end
  class Forbidden < StandardError; end
  class TenantRequired < StandardError; end

  included do
    rescue_from ActiveRecord::RecordNotFound, with: -> { render_error(:not_found, t_api(:not_found)) }
    rescue_from TenantRequired, with: -> { render_error(:not_found, t_api(:not_found)) }
    rescue_from ActiveRecord::RecordInvalid, with: ->(e) { render_validation_errors(e.record) }
    rescue_from ActiveRecord::RecordNotDestroyed, with: ->(e) { render_validation_errors(e.record) }
    rescue_from ActionController::ParameterMissing, ActionController::BadRequest,
      with: ->(e) { render_error(:bad_request, e.message) }
    rescue_from Booking::Reservation::InvalidTransition,
      with: ->(e) { render_error(:unprocessable_entity, e.message, code: "invalid_transition") }
    rescue_from Unauthenticated, with: -> { render_error(:unauthorized, t_api(:unauthorized)) }
    rescue_from Forbidden, with: ->(e) { render_error(:forbidden, e.message.presence || t_api(:forbidden)) }
    rescue_from ActionController::InvalidAuthenticityToken,
      with: -> { render_error(:forbidden, t_api(:invalid_csrf_token), code: "invalid_csrf_token") }
  end

  private
    def t_api(key, **options)
      I18n.t(key, scope: "api.errors", locale: @locale || I18n.locale, **options)
    end

    def render_error(status, message, code: nil, details: nil)
      error = { code: code || Rack::Utils::SYMBOL_TO_STATUS_CODE.key(Rack::Utils.status_code(status)).to_s, message: message }
      error[:details] = details if details
      render json: { error: error }, status: status
    end

    def render_validation_errors(record)
      I18n.with_locale(@locale || I18n.locale) { render_validation_errors_in_locale(record) }
    end

    def render_validation_errors_in_locale(record)
      render_error(:unprocessable_entity, t_api(:validation_failed), code: "validation_failed",
        details: record.errors.to_hash(true).transform_values(&:uniq))
    end
end
