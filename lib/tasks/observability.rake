namespace :observability do
  desc "Generate HTTP latency report from structured app logs"
  task performance_report: :environment do
    log_path = ENV["LOG_PATH"].presence || Rails.root.join("log/production.log").to_s
    threshold_ms = ENV.fetch("SLOW_REQUEST_THRESHOLD_MS", "750")

    unless File.exist?(log_path)
      puts "Log file not found: #{log_path}"
      exit(1)
    end

    report = Observability::PerformanceReport.new(
      lines: File.foreach(log_path),
      slow_threshold_ms: threshold_ms
    ).call

    puts "Performance report (#{Time.now.utc.iso8601})"
    puts "Source log: #{log_path}"
    puts "Slow threshold: #{threshold_ms}ms"
    puts "Total requests: #{report[:total_requests]}"
    puts "Slow requests: #{report[:slow_requests]} (#{report[:slow_ratio]}%)"
    puts ""
    puts format("%-32s %8s %8s %8s %8s %8s %8s", "Endpoint", "Count", "Avg", "P95", "Max", "Slow", "Slow%")
    puts "-" * 90

    report[:endpoints].first(20).each do |row|
      puts format(
        "%-32s %8d %8.1f %8.1f %8.1f %8d %7.1f%%",
        row[:endpoint].slice(0, 32),
        row[:count],
        row[:avg_ms],
        row[:p95_ms],
        row[:max_ms],
        row[:slow_count],
        row[:slow_ratio]
      )
    end
  end
end
