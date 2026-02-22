module Currencies
  class Repository
    include AtomicRpc

    def initialize(client:)
      @client = client
    end

    def create_with_audit_atomic(payload:, actor_id:)
      call_atomic_rpc!(
        "rpc/create_currency_with_audit_atomic",
        body: {
          p_actor_id: actor_id,
          p_code: payload[:code],
          p_name: payload[:name],
          p_symbol: payload[:symbol],
          p_rate_to_try: payload[:rate_to_try],
          p_active: payload[:active]
        }
      )
    end

    def update_with_audit_atomic(currency_id:, payload:, actor_id:)
      call_atomic_rpc!(
        "rpc/update_currency_with_audit_atomic",
        body: {
          p_actor_id: actor_id,
          p_currency_id: currency_id,
          p_code: payload[:code],
          p_name: payload[:name],
          p_symbol: payload[:symbol],
          p_rate_to_try: payload[:rate_to_try],
          p_active: payload[:active]
        }
      )
    end

    def archive_with_audit_atomic(currency_id:, actor_id:)
      call_atomic_rpc!(
        "rpc/archive_currency_with_audit_atomic",
        body: {
          p_actor_id: actor_id,
          p_currency_id: currency_id
        }
      )
    end

    def restore_with_audit_atomic(currency_id:, actor_id:)
      call_atomic_rpc!(
        "rpc/restore_currency_with_audit_atomic",
        body: {
          p_actor_id: actor_id,
          p_currency_id: currency_id
        }
      )
    end

    def code_taken?(code:, exclude_currency_id: nil)
      normalized = code.to_s.strip.upcase
      return false if normalized.blank?

      filters = [
        "deleted_at=is.null",
        "code=eq.#{Supabase::FilterValue.eq(normalized)}"
      ]
      if exclude_currency_id.present?
        filters << "id=neq.#{Supabase::FilterValue.eq(exclude_currency_id)}"
      end

      path = "currencies?select=id&#{filters.join('&')}&limit=1"
      rows = @client.get(path)
      rows.is_a?(Array) && rows.any?
    end
  end
end
