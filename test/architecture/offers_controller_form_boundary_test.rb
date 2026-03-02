require "test_helper"

class OffersControllerFormBoundaryTest < ActiveSupport::TestCase
  test "offers standard draft flow uses create form normalization for mutable payload" do
    source = File.read(Rails.root.join("app/services/offers/standart_draft_flow.rb"))

    assert_includes source, "Offers::CreateForm.new("
  end
end
