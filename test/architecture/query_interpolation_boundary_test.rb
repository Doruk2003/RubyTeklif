require "test_helper"

class QueryInterpolationBoundaryTest < ActiveSupport::TestCase
  TARGET_GLOBS = [
    "app/queries/**/*.rb",
    "app/services/**/*.rb"
  ].freeze

  test "params values are not directly interpolated into query strings" do
    violations = []

    TARGET_GLOBS.each do |glob|
      Dir[Rails.root.join(glob)].sort.each do |file|
        File.read(file).each_line.with_index(1) do |line, line_no|
          next if line.strip.start_with?("#")
          next unless line.include?("params[")
          next unless line.include?("\#{")
          next if line.include?("Supabase::FilterValue.")
          next if line.include?("URI.encode_www_form_component")

          relative = file.sub(Rails.root.to_s + File::SEPARATOR, "")
          violations << "#{relative}:#{line_no}: #{line.strip}"
        end
      end
    end

    assert_empty violations, "Direct params interpolation detected:\n#{violations.join("\n")}"
  end
end
