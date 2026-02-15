require "test_helper"

class RepositoryActorIdGuardTest < ActiveSupport::TestCase
  TARGET_REPOSITORIES = [
    "app/services/categories/repository.rb",
    "app/services/companies/repository.rb",
    "app/services/currencies/repository.rb",
    "app/services/products/repository.rb",
    "app/services/offers/repository.rb"
  ].freeze

  test "mutating repositories forward p_actor_id in rpc payloads" do
    violations = []

    TARGET_REPOSITORIES.each do |relative_path|
      source = File.read(Rails.root.join(relative_path))
      next if source.include?("p_actor_id:")

      violations << "#{relative_path}: missing p_actor_id in rpc body"
    end

    assert_empty violations, "Repository actor-id guard violations:\n#{violations.join("\n")}"
  end
end
