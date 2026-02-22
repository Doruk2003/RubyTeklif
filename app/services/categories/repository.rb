module Categories
  class Repository
    include AtomicRpc

    def initialize(client:)
      @client = client
    end

    def create_with_audit_atomic(payload:, actor_id:)
      call_atomic_rpc!(
        "rpc/create_category_with_audit_atomic",
        body: {
          p_actor_id: actor_id,
          p_code: payload[:code],
          p_name: payload[:name],
          p_active: payload[:active]
        }
      )
    end

    def update_with_audit_atomic(category_id:, payload:, actor_id:)
      call_atomic_rpc!(
        "rpc/update_category_with_audit_atomic",
        body: {
          p_actor_id: actor_id,
          p_category_id: category_id,
          p_code: payload[:code],
          p_name: payload[:name],
          p_active: payload[:active]
        }
      )
    end

    def archive_with_audit_atomic(category_id:, actor_id:)
      call_atomic_rpc!(
        "rpc/archive_category_with_audit_atomic",
        body: {
          p_actor_id: actor_id,
          p_category_id: category_id
        }
      )
    end

    def restore_with_audit_atomic(category_id:, actor_id:)
      call_atomic_rpc!(
        "rpc/restore_category_with_audit_atomic",
        body: {
          p_actor_id: actor_id,
          p_category_id: category_id
        }
      )
    end

    def code_taken?(code:, exclude_category_id: nil)
      taken_for?(:code, code, exclude_category_id: exclude_category_id)
    end

    def name_taken?(name:, exclude_category_id: nil)
      taken_for?(:name, name, exclude_category_id: exclude_category_id)
    end

    private

    def taken_for?(field, value, exclude_category_id: nil)
      normalized = value.to_s.strip
      return false if normalized.blank?

      filters = [
        "deleted_at=is.null",
        "#{field}=eq.#{Supabase::FilterValue.eq(normalized)}"
      ]
      if exclude_category_id.present?
        filters << "id=neq.#{Supabase::FilterValue.eq(exclude_category_id)}"
      end

      path = "categories?select=id&#{filters.join('&')}&limit=1"
      rows = @client.get(path)
      rows.is_a?(Array) && rows.any?
    end
  end
end
