module Companies
  class ShowQuery
    def initialize(client:)
      @client = client
    end

    def call(id)
      data = @client.get("company_with_offer_counts?id=eq.#{Supabase::FilterValue.eq(id)}&deleted_at=is.null&select=id,name,tax_number,tax_office,authorized_person,phone,email,address,description,city,country,active,total_offers_count,approved_offers_count,total_offer_amount,approved_offer_amount")
      row = data.is_a?(Array) ? data.first : nil
      return nil unless row.is_a?(Hash)

      Company.new(
        id: row["id"],
        name: row["name"],
        tax_number: row["tax_number"],
        tax_office: row["tax_office"],
        authorized_person: row["authorized_person"],
        phone: row["phone"],
        email: row["email"],
        address: row["address"],
        description: row["description"],
        city: row["city"],
        country: row["country"],
        active: row.key?("active") ? row["active"] : true,
        total_offers_count: row["total_offers_count"].to_i,
        approved_offers_count: row["approved_offers_count"].to_i,
        total_offer_amount: row["total_offer_amount"].to_f,
        approved_offer_amount: row["approved_offer_amount"].to_f,
        offers_count: row["total_offers_count"].to_i
      )
    end
  end
end
