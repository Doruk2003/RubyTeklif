module Offers
  module Status
    ALLOWED = %w[taslak surec_isliyor onaylandi reddedildi].freeze
    LABELS = {
      "taslak" => "Hazirlaniyor",
      "surec_isliyor" => "Surec Isliyor",
      "onaylandi" => "Onaylandi",
      "reddedildi" => "Red Edildi"
    }.freeze

    def self.normalize(value)
      status = value.to_s.downcase
      ALLOWED.include?(status) ? status : "surec_isliyor"
    end
  end
end
