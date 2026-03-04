module Offers
  class ShowQuery
    def initialize(client:)
      @client = client
    end

    def call(id)
      oid = id.to_s
      return nil if oid.blank?

      offer_rows = @client.get(
        "offers?id=eq.#{Supabase::FilterValue.eq(oid)}" \
        "&select=id,company_id,offer_number,offer_date,net_total,vat_total,gross_total,status,deleted_at,project,offer_type"
      )
      offer = if offer_rows.is_a?(Array)
                offer_rows.first
              elsif offer_rows.is_a?(Hash) && offer_rows["id"].present?
                offer_rows
              else
                nil
              end
      return nil unless offer.is_a?(Hash)

      company_name = fetch_company_name(offer["company_id"])
      offer["companies"] = { "name" => company_name } if company_name.present?

      item_rows = @client.get(
        "offer_items?offer_id=eq.#{Supabase::FilterValue.eq(oid)}" \
        "&deleted_at=is.null" \
        "&select=id,description,quantity,unit_price,discount_rate,line_total,products(name,vat_rate)"
      )
      offer["offer_items"] = item_rows.is_a?(Array) ? item_rows : []
      offer
    end

    private

    def fetch_company_name(company_id)
      cid = company_id.to_s
      return "" if cid.blank?

      rows = @client.get(
        "companies?id=eq.#{Supabase::FilterValue.eq(cid)}&select=name&limit=1"
      )
      row = rows.is_a?(Array) ? rows.first : nil
      row.is_a?(Hash) ? row["name"].to_s : ""
    end
  end
end
