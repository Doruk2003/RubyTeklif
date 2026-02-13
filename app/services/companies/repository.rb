module Companies
  class Repository
    def initialize(client:)
      @client = client
    end

    def create_with_audit_atomic(payload:, actor_id:)
      @client.post(
        "rpc/create_company_with_audit_atomic",
        body: {
          p_actor_id: actor_id,
          p_name: payload[:name],
          p_tax_number: payload[:tax_number],
          p_tax_office: payload[:tax_office],
          p_authorized_person: payload[:authorized_person],
          p_phone: payload[:phone],
          p_email: payload[:email],
          p_address: payload[:address],
          p_active: payload[:active]
        },
        headers: { "Prefer" => "return=representation" }
      )
    end

    def update_with_audit_atomic(company_id:, payload:, actor_id:)
      @client.post(
        "rpc/update_company_with_audit_atomic",
        body: {
          p_actor_id: actor_id,
          p_company_id: company_id,
          p_name: payload[:name],
          p_tax_number: payload[:tax_number],
          p_tax_office: payload[:tax_office],
          p_authorized_person: payload[:authorized_person],
          p_phone: payload[:phone],
          p_email: payload[:email],
          p_address: payload[:address],
          p_active: payload[:active]
        },
        headers: { "Prefer" => "return=representation" }
      )
    end

    def archive_with_audit_atomic(company_id:, actor_id:)
      @client.post(
        "rpc/archive_company_with_audit_atomic",
        body: {
          p_actor_id: actor_id,
          p_company_id: company_id
        },
        headers: { "Prefer" => "return=representation" }
      )
    end
  end
end
