module CompaniesHelper
  def phone_digits(value)
    value.to_s.gsub(/\D+/, "")
  end

  def format_phone(value)
    digits = phone_digits(value)
    return "-" if digits.blank?

    digits = "0#{digits}" if digits.length == 10
    return value.to_s if digits.length != 11

    parts = [digits[0], digits[1, 3], digits[4, 3], digits[7, 2], digits[9, 2]]
    parts.join(" ")
  end

  def format_tax_number(value)
    digits = value.to_s.gsub(/\D+/, "")
    return "-" if digits.blank?
    return value.to_s if digits.length != 10

    parts = [digits[0, 2], digits[2, 2], digits[4, 3], digits[7, 3]]
    parts.join(" ")
  end
end
