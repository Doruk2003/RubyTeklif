require "test_helper"

class OffersControllerFormBoundaryTest < ActiveSupport::TestCase
  test "offers controller uses create form normalization for mutable payload" do
    source = File.read(Rails.root.join("app/controllers/offers_controller.rb"))

    assert_includes source, "Offers::CreateForm.new("
  end
end
