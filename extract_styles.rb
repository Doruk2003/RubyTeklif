require 'fileutils'

app_dir = "d:/RubyTeklif_App/app/views"
css_file = "d:/RubyTeklif_App/app/assets/stylesheets/application.css"

files_to_process = [
  "#{app_dir}/pages/home.html.erb",
  "#{app_dir}/pages/ajanda.html.erb",
  "#{app_dir}/products/_form.html.erb",
  "#{app_dir}/products/show.html.erb"
]

all_extrated_css = "\n\n/* ========================================= */\n/* EXTRACTED STYLES FROM VIEWS (home, ajanda, products) */\n/* ========================================= */\n\n"

files_to_process.each do |file_path|
  next unless File.exist?(file_path)
  
  content = File.read(file_path, encoding: 'UTF-8')
  
  # Regex to find <style>...</style> non-greedy
  # There might be multiple style blocks, but in our case it's 1 per file based on previous view_file.
  css_blocks = content.scan(/<style(?:[^>]*)>([\s\S]*?)<\/style>/i)
  
  if css_blocks.any?
    puts "Extracting from #{file_path}..."
    css_blocks.each_with_index do |match, idx|
      all_extrated_css << "/* From #{File.basename(file_path)} (Block #{idx+1}) */\n"
      all_extrated_css << match[0].strip + "\n\n"
    end
    
    # Remove all style blocks from the view
    new_content = content.gsub(/<style(?:[^>]*)>[\s\S]*?<\/style>\s*/i, '')
    
    File.write(file_path, new_content, encoding: 'UTF-8')
    puts "Updated #{file_path}"
  end
end

File.open(css_file, "a", encoding: "UTF-8") do |f|
  f.write(all_extrated_css)
end

puts "Appended extracted styles to application.css"
