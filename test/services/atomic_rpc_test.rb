require "test_helper"

class AtomicRpcTest < ActiveSupport::TestCase
  class FakeClient
    attr_reader :path, :body, :headers

    def post(path, body:, headers:)
      @path = path
      @body = body
      @headers = headers
      []
    end
  end

  class FakeAtomicCaller
    include AtomicRpc

    def initialize(client)
      @client = client
    end

    def call(path, body)
      call_atomic_rpc!(path, body: body)
    end
  end

  test "posts with standard prefer header for atomic rpc" do
    client = FakeClient.new
    caller = FakeAtomicCaller.new(client)

    caller.call("rpc/sample_action_atomic", { foo: "bar" })

    assert_equal "rpc/sample_action_atomic", client.path
    assert_equal({ foo: "bar" }, client.body)
    assert_equal({ "Prefer" => "return=representation" }, client.headers)
  end

  test "raises system error for non-atomic rpc path" do
    caller = FakeAtomicCaller.new(FakeClient.new)

    assert_raises(ServiceErrors::System) do
      caller.call("rpc/nonatomic_action", {})
    end
  end
end
