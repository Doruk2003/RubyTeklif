require "net/http"
require "json"
require "cgi"

module Supabase
  class StorageClient
    class StorageError < StandardError; end

    def initialize(access_token:)
      @access_token = access_token.to_s
      validate_env!
    end

    def upload(bucket:, path:, io:, content_type:)
      raise StorageError, "Missing access token for storage upload" if @access_token.blank?

      uri = URI("#{ENV.fetch("SUPABASE_URL")}/storage/v1/object/#{bucket}/#{encode_path(path)}")
      request = Net::HTTP::Post.new(uri)
      request["apikey"] = ENV.fetch("SUPABASE_ANON_KEY")
      request["Authorization"] = "Bearer #{@access_token}"
      request["x-upsert"] = "false"
      request["Content-Type"] = content_type.to_s.presence || "application/octet-stream"
      request.body = io.read

      response = perform(request)
      return true if response.code.to_i.between?(200, 299)

      raise StorageError, parse_error(response)
    end

    def delete(bucket:, path:)
      raise StorageError, "Missing access token for storage delete" if @access_token.blank?

      uri = URI("#{ENV.fetch("SUPABASE_URL")}/storage/v1/object/#{bucket}/#{encode_path(path)}")
      request = Net::HTTP::Delete.new(uri)
      request["apikey"] = ENV.fetch("SUPABASE_ANON_KEY")
      request["Authorization"] = "Bearer #{@access_token}"

      response = perform(request)
      return true if response.code.to_i.between?(200, 299)
      return true if response.code.to_i == 404

      raise StorageError, parse_error(response)
    end

    private

    def encode_path(path)
      path.to_s.split("/").map { |segment| CGI.escape(segment) }.join("/")
    end

    def perform(request)
      http = Net::HTTP.new(request.uri.host, request.uri.port)
      http.use_ssl = true
      http.request(request)
    end

    def parse_error(response)
      body = response.body.to_s
      parsed = JSON.parse(body)
      parsed["message"].to_s.presence || parsed["error"].to_s.presence || "Storage request failed"
    rescue JSON::ParserError
      body.presence || "Storage request failed"
    end

    def validate_env!
      ENV.fetch("SUPABASE_URL")
      ENV.fetch("SUPABASE_ANON_KEY")
    rescue KeyError => e
      raise StorageError, "Missing ENV: #{e.message}"
    end
  end
end
