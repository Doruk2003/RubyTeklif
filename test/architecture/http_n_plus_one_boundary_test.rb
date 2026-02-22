require "test_helper"

class HttpNPlusOneBoundaryTest < ActiveSupport::TestCase
  TARGET_FILES = Dir[Rails.root.join("app/queries/**/*.rb")].sort.freeze

  test "query files avoid loop-scoped http calls that can create n+1 patterns" do
    violations = []

    TARGET_FILES.each do |file|
      lines = File.read(file).lines
      lines.each_with_index do |line, idx|
        next unless line.match?(/\b(each|map)\s+do\b/)

        window = lines[idx, 10].join
        next unless window.include?("@client.get(") || window.include?("@client.post(")

        relative = file.sub(Rails.root.to_s + File::SEPARATOR, "")
        violations << "#{relative}:#{idx + 1}"
      end
    end

    assert_empty violations, "Potential HTTP N+1 loop detected:\n#{violations.join("\n")}"
  end
end
