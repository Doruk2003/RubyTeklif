require "json"

module Observability
  # :reek:DuplicateMethodCall
  # :reek:FeatureEnvy
  # :reek:TooManyStatements
  # :reek:UtilityFunction
  # Aggregates structured request logs into endpoint latency metrics.
  class PerformanceReport
    # :reek:FeatureEnvy
    # :reek:UtilityFunction
    # Mutable accumulator for an endpoint.
    EndpointStats = Struct.new(:count, :sum, :max, :slow_count, :durations, keyword_init: true) do
      def record(duration_ms:, threshold_ms:)
        self.count += 1
        self.sum += duration_ms
        self.max = [self.max, duration_ms].max
        self.slow_count += 1 if duration_ms >= threshold_ms
        durations << duration_ms
      end

      def to_row(endpoint)
        {
          endpoint: endpoint,
          count: count,
          avg_ms: average_ms,
          p95_ms: percentile_95_ms,
          max_ms: max.round(1),
          slow_count: slow_count,
          slow_ratio: ratio(slow_count, count)
        }
      end

      private

      def average_ms
        return 0.0 if count.to_i <= 0

        (sum / count).round(1)
      end

      def percentile_95_ms
        sorted = durations.sort
        return 0.0 if sorted.empty?

        index = ((95.0 / 100.0) * (sorted.length - 1)).ceil
        sorted[index].round(1)
      end

      def ratio(part, total)
        return 0.0 if total.to_i <= 0

        ((part.to_f / total.to_f) * 100.0).round(1)
      end
    end

    def initialize(lines:, slow_threshold_ms:)
      @lines = lines
      @slow_threshold_ms = slow_threshold_ms.to_f
    end

    def call
      endpoints = Hash.new { |hash, key| hash[key] = EndpointStats.new(count: 0, sum: 0.0, max: 0.0, slow_count: 0, durations: []) }
      totals = { total_requests: 0, slow_requests: 0 }

      @lines.each { |line| record_line(line: line, endpoints: endpoints, totals: totals) }

      {
        total_requests: totals[:total_requests],
        slow_requests: totals[:slow_requests],
        slow_ratio: ratio(totals[:slow_requests], totals[:total_requests]),
        endpoints: build_endpoint_rows(endpoints)
      }
    end

    private

    def record_line(line:, endpoints:, totals:)
      event = parse_line(line)
      return unless event

      endpoint = "#{event[:method]} #{event[:path]}"
      endpoints[endpoint].record(duration_ms: event[:duration_ms], threshold_ms: @slow_threshold_ms)
      totals[:total_requests] += 1
      totals[:slow_requests] += 1 if event[:duration_ms] >= @slow_threshold_ms
    end

    # :reek:NilCheck
    def parse_line(line)
      data = JSON.parse(line)
      return nil unless data.is_a?(Hash)
      return nil unless data["event"] == "http.request"
      duration_ms = Float(data["duration_ms"], exception: false)
      return nil if duration_ms.nil?

      method = data["method"].to_s.strip
      path = data["path"].to_s.strip
      return nil if method.empty? || path.empty?

      { method: method, path: path, duration_ms: duration_ms }
    rescue JSON::ParserError, TypeError
      nil
    end

    def build_endpoint_rows(endpoints)
      endpoints.map { |endpoint, stats| stats.to_row(endpoint) }
               .sort_by { |row| [-row[:p95_ms], -row[:count], row[:endpoint]] }
    end

    def ratio(part, total)
      return 0.0 if total.to_i <= 0

      ((part.to_f / total.to_f) * 100.0).round(1)
    end
  end
end
