require "test_helper"

class QueryRubySortBoundaryTest < ActiveSupport::TestCase
  QUERY_FILES = Dir[Rails.root.join("app/queries/**/*.rb")].sort.freeze

  test "query layer avoids ruby sort_by for data ordering" do
    violations = []

    QUERY_FILES.each do |file|
      File.read(file).each_line.with_index(1) do |line, line_no|
        next if line.strip.start_with?("#")
        next unless line.include?(".sort_by")

        relative = file.sub(Rails.root.to_s + File::SEPARATOR, "")
        violations << "#{relative}:#{line_no}:#{line.strip}"
      end
    end

    assert_empty violations, "Ruby-side sort_by found in query layer:\n#{violations.join("\n")}"
  end
end
