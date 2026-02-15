module Observability
  module ErrorReporter
    module_function

    def report(error, severity: :error, context: {})
      severity_value = severity.to_s
      payload = {
        error_class: error.class.name,
        error_message: error.message.to_s,
        backtrace: Array(error.backtrace).first(8),
        severity: severity_value
      }.merge(context || {})

      case severity.to_sym
      when :info
        AppLogger.info("app.error", payload)
      when :warn, :warning
        AppLogger.warn("app.error", payload)
      else
        AppLogger.error("app.error", payload)
      end

      return unless defined?(Sentry)
      return unless sentry_enabled?
      return unless capture_in_sentry?(error: error, severity: severity_value)

      Sentry.with_scope do |scope|
        scope.set_tags(
          {
            request_id: Current.request_id,
            user_id: Current.user&.id,
            severity: severity_value
          }.compact
        )
        scope.set_context("app_context", (context || {}).transform_keys(&:to_s))
        Sentry.capture_exception(error)
      end
    rescue StandardError
      nil
    end

    def sentry_enabled?
      ENV["SENTRY_DSN"].present?
    end

    def capture_in_sentry?(error:, severity:)
      return true unless error.is_a?(ServiceErrors::Base)
      return false if error.is_a?(ServiceErrors::Validation)
      return false if error.is_a?(ServiceErrors::Policy)

      severity == "error"
    end
  end
end
