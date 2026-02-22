module Brands
  class Repository
    include AtomicRpc

    def initialize(client:)
      @client = client
    end

    def create_with_audit_atomic(payload:, actor_id:)
      call_atomic_rpc!(
        "rpc/create_brand_with_audit_atomic",
        body: {
          p_actor_id: actor_id,
          p_code: payload[:code],
          p_name: payload[:name],
          p_active: payload[:active]
        }
      )
    end

    def code_taken?(code:)
      taken_for?(:code, code)
    end

    def name_taken?(name:)
      taken_for?(:name, name)
    end

    private

    def taken_for?(field, value)
      normalized = value.to_s.strip
      return false if normalized.blank?

      path = "brands?select=id&deleted_at=is.null&#{field}=eq.#{Supabase::FilterValue.eq(normalized)}&limit=1"
      rows = @client.get(path)
      rows.is_a?(Array) && rows.any?
    end
  end
end
