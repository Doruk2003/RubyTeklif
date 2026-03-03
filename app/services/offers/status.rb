module Offers
  module Status
    ALLOWED = %w[taslak beklemede onaylandi reddedildi].freeze
    LABELS = {
      "taslak" => "Hazirlaniyor",
      "beklemede" => "Surec Isliyor",
      "onaylandi" => "Onaylandi",
      "reddedildi" => "Red Edildi"
    }.freeze

    def self.normalize(value)
      status = value.to_s.downcase
      return "beklemede" if status == "surec_isliyor"

      ALLOWED.include?(status) ? status : "beklemede"
    end
  end
end
