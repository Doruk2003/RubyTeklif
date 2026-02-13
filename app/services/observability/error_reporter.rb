module Observability
  module ErrorReporter
    module_function

    def report(error, severity: :error, context: {})
      payload = {
        error_class: error.class.name,
        error_message: error.message.to_s,
        backtrace: Array(error.backtrace).first(8),
        severity: severity.to_s
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

      Sentry.with_scope do |scope|
        (context || {}).each { |k, v| scope.set_tag(k.to_s, v.to_s) }
        Sentry.capture_exception(error)
      end
    rescue StandardError
      nil
    end
  end
end
