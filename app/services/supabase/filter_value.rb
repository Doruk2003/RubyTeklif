require "uri"

module Supabase
  module FilterValue
    module_function

    def eq(value)
      URI.encode_www_form_component(value.to_s)
    end

    def ilike(value)
      escaped = value.to_s.gsub("%", "\\%").gsub("_", "\\_")
      URI.encode_www_form_component(escaped)
    end

    def uuid(value)
      raw = value.to_s
      return nil unless raw.match?(/\A[0-9a-fA-F-]{36}\z/)

      raw
    end

    def uuid_list(values)
      Array(values).map { |v| uuid(v) }.compact.uniq
    end
  end
end
