# lib/tasks/schema_update.rake

namespace :db do
  desc "Update Supabase schema JSON, DOT and PNG automatically"
  task :update_all do
    puts "Step 1: Generate schema_map.json from supabase_schema.sql..."
    system("ruby lib/tasks/schema_mapper.rb")

    puts "Step 2: Generate ER diagram DOT and PNG..."
    system("ruby lib/tasks/schema_erd.rb")

    puts "All done! schema_map.json, schema_map.dot and schema_map.png are updated."
  end
end
