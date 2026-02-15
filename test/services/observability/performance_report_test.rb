require "test_helper"

module Observability
  class PerformanceReportTest < ActiveSupport::TestCase
    test "builds endpoint metrics from structured request logs" do
      lines = [
        { event: "http.request", method: "GET", path: "/offers", duration_ms: 120.0 }.to_json,
        { event: "http.request", method: "GET", path: "/offers", duration_ms: 240.0 }.to_json,
        { event: "http.request", method: "POST", path: "/companies", duration_ms: 980.0 }.to_json,
        { event: "other.event", method: "GET", path: "/ignored", duration_ms: 50.0 }.to_json,
        "not-json"
      ]

      result = PerformanceReport.new(lines: lines, slow_threshold_ms: 700).call
      offers = result[:endpoints].find { |row| row[:endpoint] == "GET /offers" }
      companies = result[:endpoints].find { |row| row[:endpoint] == "POST /companies" }

      assert_equal 3, result[:total_requests]
      assert_equal 1, result[:slow_requests]
      assert_equal 33.3, result[:slow_ratio]

      assert_equal 2, offers[:count]
      assert_equal 180.0, offers[:avg_ms]
      assert_equal 240.0, offers[:p95_ms]
      assert_equal 240.0, offers[:max_ms]
      assert_equal 0, offers[:slow_count]
      assert_equal 0.0, offers[:slow_ratio]

      assert_equal 1, companies[:count]
      assert_equal 980.0, companies[:avg_ms]
      assert_equal 980.0, companies[:p95_ms]
      assert_equal 980.0, companies[:max_ms]
      assert_equal 1, companies[:slow_count]
      assert_equal 100.0, companies[:slow_ratio]
    end
  end
end
