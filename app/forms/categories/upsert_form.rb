module Categories
  class UpsertForm
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :code, :string
    attribute :name, :string
    attribute :active

    validates :name, presence: true, length: { maximum: 100 }

    def normalized_attributes
      generated_code = code.to_s.strip.presence || generated_code_from_name(name)

      {
        code: generated_code,
        name: name.to_s.strip,
        active: normalize_active(active)
      }
    end

    private

    def normalize_active(value)
      return true if value.nil?

      value.to_s.in?(%w[1 true on])
    end

    def generated_code_from_name(raw_name)
      letters = I18n.transliterate(raw_name.to_s).upcase.gsub(/[^A-Z0-9]/, "")
      prefix = letters.first(3).to_s.ljust(3, "X")
      "#{prefix}-001"
    end
  end
end
