require "test_helper"

class ReleaseSmokeScriptTest < ActiveSupport::TestCase
  test "release smoke script includes core gate steps" do
    source = File.read(Rails.root.join("bin/release_smoke"))

    assert_includes source, "bundle\", \"exec\", \"rubocop\""
    assert_includes source, "bundle\", \"exec\", \"reek\", \"app\""
    assert_includes source, "bundle\", \"exec\", \"brakeman\""
    assert_includes source, "bundle\", \"exec\", \"rails\", \"test\", \"test/architecture\""
    assert_includes source, "bundle\", \"exec\", \"rails\", \"test\""
    assert_includes source, "--with-system"
  end
end
