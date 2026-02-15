require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false

  config.action_controller.perform_caching = true
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }
  config.active_storage.service = :local

  config.log_tags = [:request_id]
  config.logger = ActiveSupport::TaggedLogging.logger(STDOUT)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
  config.silence_healthcheck_path = "/up"
  config.active_support.report_deprecations = false

  cache_store_adapter = ENV.fetch("CACHE_STORE_ADAPTER", "solid_cache_store").to_s
  if cache_store_adapter == "redis_cache_store"
    config.cache_store = :redis_cache_store, {
      url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"),
      namespace: "rubyteklif:cache:staging"
    }
  else
    config.cache_store = :solid_cache_store
  end

  queue_adapter = ENV.fetch("ACTIVE_JOB_QUEUE_ADAPTER", "sidekiq").to_s
  config.active_job.queue_adapter = queue_adapter.to_sym
  if queue_adapter == "solid_queue"
    config.solid_queue.connects_to = { database: { writing: :queue } }
  end

  config.action_mailer.default_url_options = {
    host: ENV.fetch("APP_HOST", "staging.example.com")
  }

  config.i18n.fallbacks = true
  config.active_record.dump_schema_after_migration = false
  config.active_record.attributes_for_inspect = [:id]
end
