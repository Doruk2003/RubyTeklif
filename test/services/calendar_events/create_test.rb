require "test_helper"

module CalendarEvents
  class CreateTest < ActiveSupport::TestCase
    class FakeRepository
      attr_reader :payload

      def initialize(response)
        @response = response
      end

      def create!(payload:)
        @payload = payload
        @response
      end
    end

    test "creates event with normalized payload" do
      repository = FakeRepository.new([{ "id" => "evt-1", "title" => "Demo" }])
      service = CalendarEvents::Create.new(repository: repository)

      result = service.call(
        form_payload: { event_date: "2026-03-01", title: "  Demo  ", description: "  Aciklama  ", color: "#22c55e" },
        user_id: "user-1"
      )

      assert_equal "evt-1", result["id"]
      assert_equal "2026-03-01", repository.payload[:event_date]
      assert_equal "Demo", repository.payload[:title]
      assert_equal "Aciklama", repository.payload[:description]
      assert_equal "user-1", repository.payload[:user_id]
    end

    test "raises validation error for invalid form" do
      repository = FakeRepository.new([{ "id" => "evt-1" }])
      service = CalendarEvents::Create.new(repository: repository)

      assert_raises(ServiceErrors::Validation) do
        service.call(form_payload: { event_date: "", title: "" }, user_id: "user-1")
      end
    end
  end
end
