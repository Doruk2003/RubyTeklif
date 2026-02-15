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
          p_active: payload[:active]
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
          p_active: payload[:active]
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
  end
end
