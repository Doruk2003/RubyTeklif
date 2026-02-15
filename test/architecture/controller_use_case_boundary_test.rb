require "test_helper"

class ControllerUseCaseBoundaryTest < ActiveSupport::TestCase
  EXPECTED_PATTERNS = {
    "app/controllers/companies_controller.rb" => /Catalog::UseCases::Companies::/,
    "app/controllers/products_controller.rb" => /Catalog::UseCases::Products::/,
    "app/controllers/currencies_controller.rb" => /Catalog::UseCases::Currencies::/,
    "app/controllers/categories_controller.rb" => /Catalog::UseCases::Categories::/,
    "app/controllers/offers_controller.rb" => /Sales::UseCases::Offers::/
  }.freeze

  DISALLOWED_DIRECT_SERVICE_PATTERNS = [
    /(?<!UseCases::)Companies::(Create|Update|Destroy|Restore)\.new/,
    /(?<!UseCases::)Products::(Create|Update|Destroy|Restore)\.new/,
    /(?<!UseCases::)Currencies::(Create|Update|Destroy|Restore)\.new/,
    /(?<!UseCases::)Categories::(Create|Update|Destroy|Restore)\.new/,
    /(?<!UseCases::)Offers::(Create|Update|Destroy|Restore)\.new/
  ].freeze

  test "core controllers call domain use-cases for mutating actions" do
    violations = []

    EXPECTED_PATTERNS.each do |relative_path, expected_pattern|
      source = File.read(Rails.root.join(relative_path))
      violations << "#{relative_path}: missing use-case namespace call" unless source.match?(expected_pattern)

      if DISALLOWED_DIRECT_SERVICE_PATTERNS.any? { |pattern| source.match?(pattern) }
        violations << "#{relative_path}: direct service call detected"
      end
    end

    assert_empty violations, "Controller use-case boundary violations:\n#{violations.join("\n")}"
  end
end
