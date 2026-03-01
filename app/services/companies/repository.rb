module Companies
  class Repository
    include AtomicRpc

    def initialize(client:)
      @client = client
    end

    def create_with_audit_atomic(payload:, actor_id:)
      call_atomic_rpc!(
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
          p_active: payload[:active],
          p_description: payload[:description],
          p_city: payload[:city],
          p_country: payload[:country]
        }
      )
    end

    def update_with_audit_atomic(company_id:, payload:, actor_id:)
      call_atomic_rpc!(
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
          p_active: payload[:active],
          p_description: payload[:description],
          p_city: payload[:city],
          p_country: payload[:country]
        }
      )
    end

    def archive_with_audit_atomic(company_id:, actor_id:)
      call_atomic_rpc!(
        "rpc/archive_company_with_audit_atomic",
        body: {
          p_actor_id: actor_id,
          p_company_id: company_id
        }
      )
    end

    def restore_with_audit_atomic(company_id:, actor_id:)
      call_atomic_rpc!(
        "rpc/restore_company_with_audit_atomic",
        body: {
          p_actor_id: actor_id,
          p_company_id: company_id
        }
      )
    end

    def tax_number_taken?(tax_number:, exclude_company_id: nil)
      return false if tax_number.to_s.strip.blank?

      filters = [
        "tax_number=eq.#{Supabase::FilterValue.eq(tax_number.to_s.strip)}"
      ]
      if exclude_company_id.present?
        filters << "id=neq.#{Supabase::FilterValue.eq(exclude_company_id)}"
      end

      path = "companies?select=id&#{filters.join('&')}&limit=1"
      rows = @client.get(path)
      return false unless rows.is_a?(Array)

      rows.any?
    end
  end
end
