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
  end
end
