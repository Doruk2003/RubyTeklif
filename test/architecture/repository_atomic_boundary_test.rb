require "test_helper"

class RepositoryAtomicBoundaryTest < ActiveSupport::TestCase
  WRITE_PATTERNS = [
    /\b@client\.post\(/,
    /\b@client\.patch\(/,
    /\b@client\.delete\(/,
    /\bclient\.post\(/,
    /\bclient\.patch\(/,
    /\bclient\.delete\(/
  ].freeze

  TARGET_REPOSITORIES = [
    "app/services/categories/repository.rb",
    "app/services/companies/repository.rb",
    "app/services/currencies/repository.rb",
    "app/services/products/repository.rb"
  ].freeze

  test "core repositories avoid direct write calls and use atomic rpc wrapper" do
    violations = []

    TARGET_REPOSITORIES.each do |relative_path|
      absolute_path = Rails.root.join(relative_path)
      source = File.read(absolute_path)

      if WRITE_PATTERNS.any? { |pattern| source.match?(pattern) }
        violations << "#{relative_path}: direct client write call detected"
      end

      unless source.include?("include AtomicRpc")
        violations << "#{relative_path}: missing AtomicRpc include"
      end
    end

    assert_empty violations, "Repository atomic boundary violations:\n#{violations.join("\n")}"
  end
end
