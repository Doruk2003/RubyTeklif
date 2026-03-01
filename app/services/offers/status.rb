module Offers
  module Status
    ALLOWED = %w[surec_isliyor onaylandi reddedildi].freeze
    LABELS = {
      "surec_isliyor" => "Süreç İşliyor",
      "onaylandi" => "Onaylandı",
      "reddedildi" => "Red Edildi"
    }.freeze

    def self.normalize(value)
      status = value.to_s.downcase
      ALLOWED.include?(status) ? status : "surec_isliyor"
    end
  end
end
