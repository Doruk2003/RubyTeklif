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
        at: Time.now.utc.iso8601
      }.merge(payload || {})

      Rails.logger.public_send(level, line.to_json)
    rescue StandardError
      nil
    end
  end
end
