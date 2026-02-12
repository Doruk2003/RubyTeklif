module Offers
  module Status
    ALLOWED = %w[taslak gonderildi beklemede onaylandi reddedildi].freeze

    def self.normalize(value)
      status = value.to_s.downcase
      ALLOWED.include?(status) ? status : "taslak"
    end
  end
end
