require "test_helper"

class ControllerBoundaryTest < ActiveSupport::TestCase
  DISALLOWED_PATTERNS = [
    /\bclient\.(get|post|patch|delete)\(/,
    /\b@client\.(get|post|patch|delete)\(/,
    /\bsupabase_user_client\.(get|post|patch|delete)\(/
  ].freeze

  test "controllers do not perform direct supabase data access" do
    files = Dir[Rails.root.join("app/controllers/**/*.rb")].sort
    violations = []

    files.each do |file|
      File.read(file).each_line.with_index(1) do |line, line_no|
        next if line.strip.start_with?("#")

        if DISALLOWED_PATTERNS.any? { |pattern| line.match?(pattern) }
          violations << "#{file.sub(Rails.root.to_s + File::SEPARATOR, "")}:#{line_no}:#{line.strip}"
        end
      end
    end

    assert_empty violations, "Direct Supabase access found in controllers:\n#{violations.join("\n")}"
  end
end
