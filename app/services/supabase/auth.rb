require "net/http"
require "json"

module Supabase
  class Auth
    class AuthError < StandardError; end

    def initialize
      @base = ENV.fetch("SUPABASE_URL")
      @anon_key = ENV.fetch("SUPABASE_ANON_KEY")
      @service_key = ENV.fetch("SUPABASE_SERVICE_ROLE_KEY")
    end

    def sign_in(email:, password:)
      uri = URI("#{@base}/auth/v1/token?grant_type=password")
      req = Net::HTTP::Post.new(uri)
      req["apikey"] = @anon_key
      req["Content-Type"] = "application/json"
      req.body = { email: email, password: password }.to_json

      response = request(req)
      raise AuthError, response["error_description"].to_s if response.is_a?(Hash) && response["error"].present?

      response
    end

    def user(access_token)
      uri = URI("#{@base}/auth/v1/user")
      req = Net::HTTP::Get.new(uri)
      req["apikey"] = @anon_key
      req["Authorization"] = "Bearer #{access_token}"

      request(req)
    end

    def sign_out(access_token)
      uri = URI("#{@base}/auth/v1/logout")
      req = Net::HTTP::Post.new(uri)
      req["apikey"] = @anon_key
      req["Authorization"] = "Bearer #{access_token}"
      req["Content-Type"] = "application/json"
      req.body = "{}"

      request(req)
    end

    def send_recovery(email:)
      uri = URI("#{@base}/auth/v1/recover")
      req = Net::HTTP::Post.new(uri)
      req["apikey"] = @anon_key
      req["Content-Type"] = "application/json"
      req.body = { email: email }.to_json

      response = request(req)
      if response.is_a?(Hash) && (response["error"].present? || response["message"].present?)
        message = response["error_description"].presence || response["message"].presence || response["error"].to_s || response["msg"].to_s
        raise AuthError, message.presence || response.inspect
      end

      response
    end

    def create_user(email:, password:, role: "admin")
      uri = URI("#{@base}/auth/v1/admin/users")
      req = Net::HTTP::Post.new(uri)
      req["apikey"] = @service_key
      req["Authorization"] = "Bearer #{@service_key}"
      req["Content-Type"] = "application/json"
      req.body = {
        email: email,
        password: password,
        email_confirm: true,
        user_metadata: { role: role }
      }.to_json

      response = request(req)
      if response.is_a?(Hash) && (response["error"].present? || response["message"].present?)
        message = response["error_description"].presence || response["message"].presence || response["error"].to_s || response["msg"].to_s
        raise AuthError, message.presence || response.inspect
      end

      unless response.is_a?(Hash) && (response["id"].present? || response.dig("user", "id").present?)
        raise AuthError, "Supabase yaniti beklenmedik: #{response.inspect}"
      end

      response
    end

    def refresh(refresh_token)
      uri = URI("#{@base}/auth/v1/token?grant_type=refresh_token")
      req = Net::HTTP::Post.new(uri)
      req["apikey"] = @anon_key
      req["Content-Type"] = "application/json"
      req.body = { refresh_token: refresh_token }.to_json

      response = request(req)
      raise AuthError, response["error_description"].to_s if response.is_a?(Hash) && response["error"].present?

      response
    end

    private

    def request(req)
      http = Net::HTTP.new(req.uri.host, req.uri.port)
      http.use_ssl = true
      response = http.request(req)
      JSON.parse(response.body.to_s)
    rescue JSON::ParserError
      response.body
    end
  end
end
