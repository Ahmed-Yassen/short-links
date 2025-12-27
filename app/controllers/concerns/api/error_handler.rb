module Api
  module ErrorHandler
    extend ActiveSupport::Concern
    included do
      rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable_entity
      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActionController::ParameterMissing, ShortLink::BlankUrlError, with: :render_bad_request
    end

    private

    def render_unprocessable_entity(exception)
      summary = exception.record.errors.full_messages.to_sentence || I18n.t("api.errors.unprocessable_entity")
      details = exception.record.errors.messages

      render_error(summary, :unprocessable_entity, details)
    end

    def render_not_found(exception)
      resource = exception.model&.demodulize&.underscore&.humanize || "Resource"
      message = I18n.t("api.errors.not_found", resource: resource)

      render_error(message, :not_found)
    end

    def render_bad_request(exception)
      message = exception.message || I18n.t("api.errors.bad_request")
      render_error(message, :bad_request)
    end

    def render_error(message, status, details = nil)
      payload = { error: message }

      payload[:errors] = details if details.present?

      render json: payload, status: status
    end
  end
end
