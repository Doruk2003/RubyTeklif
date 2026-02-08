# app/services/supabase/client.rb

require "net/http"
require "json"

module Supabase
  class Client
    class ConfigurationError < StandardError; end

    def initialize(role: :anon)
      @role = role
      validate_env!
    end

    def get(path)
      request(Net::HTTP::Get.new(uri(path)))
    end

    def get_with_response(path, headers: {})
      req = Net::HTTP::Get.new(uri(path))
      headers.each { |k, v| req[k] = v }
      request(req, with_response: true)
    end

    def post(path, body:)
      req = Net::HTTP::Post.new(uri(path))
      req.body = body.to_json
      req["Content-Type"] = "application/json"
      request(req)
    end

    private

    def request(req, with_response: false)
      req["apikey"] = api_key
      req["Authorization"] = "Bearer #{api_key}"

      http = Net::HTTP.new(req.uri.host, req.uri.port)
      http.use_ssl = true

      response = http.request(req)
      body = JSON.parse(response.body) rescue response.body
      with_response ? [body, response] : body
    end

    def uri(path)
      URI("#{ENV.fetch("SUPABASE_URL")}/rest/v1/#{path}")
    end

    def api_key
      case @role
      when :anon
        ENV.fetch("SUPABASE_ANON_KEY")
      when :service
        ENV.fetch("SUPABASE_SERVICE_ROLE_KEY")
      else
        raise ArgumentError, "Unknown role: #{@role}"
      end
    end

    def validate_env!
      ENV.fetch("SUPABASE_URL")
      ENV.fetch("SUPABASE_ANON_KEY")
      ENV.fetch("SUPABASE_SERVICE_ROLE_KEY")
    rescue KeyError => e
      raise ConfigurationError, "Missing ENV: #{e.message}"
    end
  end
end
