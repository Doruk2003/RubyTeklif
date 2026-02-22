namespace :quality do
  desc "Run mandatory architecture and data-access guard tests"
  task guard: :environment do
    commands = [
      "bundle exec rails test test/architecture",
      "bundle exec rails test test/queries",
      "bundle exec rails test test/services/query_cache_invalidator_test.rb",
      "bundle exec rails test test/services/dashboard_service_test.rb"
    ]

    commands.each do |command|
      puts "Running: #{command}"
      sh command
    end
  end
end
