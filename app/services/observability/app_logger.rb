require "json"

module Observability
  module AppLogger
    module_function

    def info(event, payload = {})
      log(:info, event, payload)
    end

    def warn(event, payload = {})
      log(:warn, event, payload)
    end

    def error(event, payload = {})
      log(:error, event, payload)
    end

    def log(level, event, payload = {})
      line = {
        event: event.to_s,
        at: Time.now.utc.iso8601,
        severity: level.to_s
      }.merge(default_context).merge(payload || {})

      Rails.logger.public_send(level, line.to_json)
    rescue StandardError
      nil
    end

    def default_context
      {
        env: Rails.env,
        request_id: Current.request_id,
        user_id: Current.user&.id
      }.compact
    end
  end
end
