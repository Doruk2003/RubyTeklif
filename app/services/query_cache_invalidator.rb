class QueryCacheInvalidator
  def initialize(cache: Rails.cache)
    @cache = cache
  end

  def invalidate_companies!(user_id:)
    uid = user_id.to_s
    return if uid.blank?

    delete("queries/companies/v2/user:#{uid}/*")
    delete("offers/form/companies/v1/user:#{uid}*")
  end

  def invalidate_products!(user_id:)
    uid = user_id.to_s
    return if uid.blank?

    delete("queries/products/v1/user:#{uid}/*")
    delete("offers/form/products/v1/user:#{uid}/*")
  end

  def invalidate_currencies!(user_id:)
    uid = user_id.to_s
    return if uid.blank?

    delete("queries/currencies/v1/user:#{uid}/*")
    delete("currencies/options/v1/user:#{uid}/*")
    delete("queries/products/v1/user:#{uid}/*")
  end

  def invalidate_categories!(user_id:)
    uid = user_id.to_s
    return if uid.blank?

    delete("categories/options/v1/user:#{uid}/*")
    delete("offers/form/products/v1/user:#{uid}/*")
    delete("queries/products/v1/user:#{uid}/*")
  end

  def invalidate_brands!(user_id:)
    uid = user_id.to_s
    return if uid.blank?

    delete("brands/options/v1/user:#{uid}/*")
    delete("queries/products/v1/user:#{uid}/*")
  end

  def invalidate_offers!(user_id:)
    uid = user_id.to_s
    return if uid.blank?

    delete("queries/offers/v1/user:#{uid}/*")
    delete("queries/companies/v2/user:#{uid}/*")
  end

  private

  def delete(pattern)
    @cache.delete_matched(pattern)
  end
end
