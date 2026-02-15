require "test_helper"

module Admin
  module ActivityLogs
    class ExportFormTest < ActiveSupport::TestCase
      test "compacts blank fields" do
        form = Admin::ActivityLogs::ExportForm.new(
          event_action: "offers.create",
          actor: "",
          target: "off-1",
          target_type: "offer",
          from: nil,
          to: "2026-02-15"
        )

        assert_equal(
          {
            event_action: "offers.create",
            target: "off-1",
            target_type: "offer",
            to: "2026-02-15"
          },
          form.to_h
        )
      end
    end
  end
end
