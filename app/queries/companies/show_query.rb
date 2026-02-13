module Companies
  class ShowQuery
    def initialize(client:)
      @client = client
    end

    def call(id)
      data = @client.get("companies?id=eq.#{id}&select=id,name,tax_number,tax_office,authorized_person,phone,email,address,active")
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
        active: row.key?("active") ? row["active"] : true,
        offers_count: 0
      )
    end
  end
end

