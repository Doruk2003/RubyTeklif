# lib/tasks/schema_erd.rb

require "json"

class ERDiagram
  # JSON ve çıktı dosyaları
  JSON_FILE = File.expand_path("../../db/schema_map.json", __dir__)
  OUTPUT_DOT = File.expand_path("../../db/schema_map.dot", __dir__)
  OUTPUT_PNG = File.expand_path("../../db/schema_map.png", __dir__)

  # Windows için Graphviz dot.exe tam yolu
  GRAPHVIZ_PATH = "D:/Program Files/Graphviz/bin/dot.exe" # → kendi kurulum yoluna göre güncelle

  def self.run
    new.run
  end

  def run
    json = JSON.parse(File.read(JSON_FILE))
    tables = json["tables"] || {}

    dot_content = generate_dot(tables)

    # DOT dosyasını yaz
    File.write(OUTPUT_DOT, dot_content)
    puts "DOT file generated at #{OUTPUT_DOT}"

    # PNG üret (Windows tam yol kullanılıyor)
    if File.exist?(GRAPHVIZ_PATH)
      system("\"#{GRAPHVIZ_PATH}\" -Tpng \"#{OUTPUT_DOT}\" -o \"#{OUTPUT_PNG}\"")
      puts "ER Diagram PNG generated at #{OUTPUT_PNG}"
    else
      puts "Graphviz dot.exe not found at #{GRAPHVIZ_PATH}. Update the path in the script."
    end
  end

  private

  def generate_dot(tables)
    dot = "digraph ERDiagram {\n"
    dot << "  rankdir=LR;\n"
    dot << "  node [shape=record, fontname=Arial];\n\n"

    # Tablolar
    tables.each do |table_name, info|
      columns = info["columns"].map { |c| "+ #{c}" }.join("\\l") + "\\l"
      dot << "  #{table_name} [label=\"{#{table_name}|#{columns}}\"];\n"
    end

    dot << "\n"

    # İlişkiler
    tables.each do |table_name, info|
      info["foreign_keys"].each do |fk|
        dot << "  #{table_name} -> #{fk['references_table']} [label=\"#{fk['column']}\"];\n"
      end
    end

    dot << "}\n"
    dot
  end
end

# Script çalıştırıldığında
if __FILE__ == $PROGRAM_NAME
  ERDiagram.run
end