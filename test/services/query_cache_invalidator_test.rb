require "test_helper"

class QueryCacheInvalidatorTest < ActiveSupport::TestCase
  class FakeCache
    attr_reader :patterns

    def initialize
      @patterns = []
    end

    def delete_matched(pattern)
      @patterns << pattern
    end
  end

  test "invalidates companies-related cache keys" do
    cache = FakeCache.new
    QueryCacheInvalidator.new(cache: cache).invalidate_companies!(user_id: "usr-1")

    assert_includes cache.patterns, "queries/companies/v2/user:usr-1/*"
    assert_includes cache.patterns, "offers/form/companies/v1/user:usr-1*"
  end

  test "invalidates products-related cache keys" do
    cache = FakeCache.new
    QueryCacheInvalidator.new(cache: cache).invalidate_products!(user_id: "usr-1")

    assert_includes cache.patterns, "queries/products/v1/user:usr-1/*"
    assert_includes cache.patterns, "offers/form/products/v1/user:usr-1/*"
  end

  test "invalidates currencies-related cache keys" do
    cache = FakeCache.new
    QueryCacheInvalidator.new(cache: cache).invalidate_currencies!(user_id: "usr-1")

    assert_includes cache.patterns, "queries/currencies/v1/user:usr-1/*"
    assert_includes cache.patterns, "currencies/options/v1/user:usr-1/*"
    assert_includes cache.patterns, "queries/products/v1/user:usr-1/*"
  end

  test "invalidates categories-related cache keys" do
    cache = FakeCache.new
    QueryCacheInvalidator.new(cache: cache).invalidate_categories!(user_id: "usr-1")

    assert_includes cache.patterns, "categories/options/v1/user:usr-1/*"
    assert_includes cache.patterns, "offers/form/products/v1/user:usr-1/*"
    assert_includes cache.patterns, "queries/products/v1/user:usr-1/*"
  end

  test "invalidates brands-related cache keys" do
    cache = FakeCache.new
    QueryCacheInvalidator.new(cache: cache).invalidate_brands!(user_id: "usr-1")

    assert_includes cache.patterns, "brands/options/v1/user:usr-1/*"
    assert_includes cache.patterns, "queries/products/v1/user:usr-1/*"
  end

  test "invalidates offers-related cache keys" do
    cache = FakeCache.new
    QueryCacheInvalidator.new(cache: cache).invalidate_offers!(user_id: "usr-1")

    assert_includes cache.patterns, "queries/offers/v1/user:usr-1/*"
    assert_includes cache.patterns, "queries/companies/v2/user:usr-1/*"
  end
end
