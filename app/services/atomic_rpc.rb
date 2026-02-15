 # Enforces atomic RPC contract for critical multi-step mutations.
module AtomicRpc
  private

  def call_atomic_rpc!(path, body:)
    rpc_path = path.to_s
    unless rpc_path.start_with?("rpc/") && rpc_path.include?("_atomic")
      raise ServiceErrors::System.new(user_message: "Atomic RPC sozlesmesi ihlali.")
    end

    @client.post(
      rpc_path,
      body: body,
      headers: { "Prefer" => "return=representation" }
    )
  end
end
