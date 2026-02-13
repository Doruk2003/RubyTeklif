class AuditLog
  def initialize(client: Supabase::Client.new(role: :service))
    @client = client
  end

  def log(action:, actor_id:, target_id:, target_type:, metadata: {})
    return if action.to_s.blank?
    return if actor_id.to_s.blank?

    payload = {
      action: action,
      actor_id: actor_id,
      target_id: target_id.to_s,
      target_type: target_type.to_s,
      metadata: normalize_metadata(metadata),
      created_at: Time.now.utc.iso8601
    }
    @client.post("activity_logs", body: payload, headers: { "Prefer" => "return=minimal" })
  rescue StandardError
    nil
  end

  private

  def normalize_metadata(metadata)
    return metadata if metadata.is_a?(Hash) || metadata.is_a?(Array)

    { value: metadata.to_s }
  end
end
