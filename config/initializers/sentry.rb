if ENV["SENTRY_DSN"].present?
  if defined?(Sentry)
    Sentry.init do |config|
      config.dsn = ENV["SENTRY_DSN"]
      config.environment = ENV.fetch("APP_ENV", Rails.env)
      config.enabled_environments = %w[production staging]
      config.breadcrumbs_logger = [:active_support_logger]
      config.traces_sample_rate = ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", "0.0").to_f
    end
  else
    Rails.logger.warn("SENTRY_DSN is set but sentry gem is not loaded.")
  end
end
