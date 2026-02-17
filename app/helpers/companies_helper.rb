module CompaniesHelper
  def phone_digits(value)
    value.to_s.gsub(/\D+/, "")
  end

  def format_phone(value)
    digits = phone_digits(value)
    return "-" if digits.blank?

    # Normalize common TR variants: 5XXXXXXXXX, 90XXXXXXXXXX, 0090XXXXXXXXXX.
    digits = "0#{digits}" if digits.length == 10 && digits.start_with?("5")
    digits = "0#{digits[2, 10]}" if digits.length == 12 && digits.start_with?("90")
    digits = "0#{digits[4, 10]}" if digits.length == 14 && digits.start_with?("0090")
    return value.to_s unless digits.length == 11

    parts = [digits[0], digits[1, 3], digits[4, 3], digits[7, 2], digits[9, 2]]
    parts.join(" ")
  end

  def format_tax_number(value)
    digits = value.to_s.gsub(/\D+/, "")
    return "-" if digits.blank?

    if digits.length == 10
      parts = [digits[0, 2], digits[2, 2], digits[4, 3], digits[7, 3]]
      return parts.join(" ")
    end

    if digits.length == 11
      parts = [digits[0, 3], digits[3, 3], digits[6, 3], digits[9, 2]]
      return parts.join(" ")
    end

    value.to_s
  end
end
