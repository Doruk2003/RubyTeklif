require "test_helper"

class QuerySilentFallbackBoundaryTest < ActiveSupport::TestCase
  QUERY_FILES = Dir[Rails.root.join("app/queries/**/*.rb")].sort.freeze

  test "query layer does not swallow errors with empty fallback values" do
    violations = []

    QUERY_FILES.each do |file|
      lines = File.read(file).lines
      lines.each_with_index do |line, idx|
        next unless line.include?("rescue StandardError")

        window = lines[idx, 8].join
        next unless window.match?(/\b(return\s+)?(\[\]|\{\}|nil)\b/)

        relative = file.sub(Rails.root.to_s + File::SEPARATOR, "")
        violations << "#{relative}:#{idx + 1}"
      end
    end

    assert_empty violations, "Silent fallback rescue detected in query layer:\n#{violations.join("\n")}"
  end
end
