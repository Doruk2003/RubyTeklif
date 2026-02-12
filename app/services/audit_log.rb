class AuditLog
  def initialize(client: Supabase::Client.new(role: :service))
    @client = client
  end

  def log(action:, actor_id:, target_id:, metadata: {})
    payload = {
      action: action,
      actor_id: actor_id,
      target_id: target_id,
      metadata: metadata.to_json,
      created_at: Time.now.utc.iso8601
    }
    @client.post("activity_logs", body: payload, headers: { "Prefer" => "return=minimal" })
  rescue StandardError
    nil
  end
end
