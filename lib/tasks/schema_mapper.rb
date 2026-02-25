# lib/tasks/schema_mapper.rb

require "json"

class SchemaMapper
  SCHEMA_FILE = File.expand_path("../../db/supabase_schema.sql", __dir__)
  OUTPUT_FILE = File.expand_path("../../db/schema_map.json", __dir__)

  def self.run
    new.run
  end

  def run
    sql = File.read(SCHEMA_FILE)

    tables = extract_tables(sql)
    foreign_keys = extract_foreign_keys(sql)

    attach_foreign_keys(tables, foreign_keys)

    File.write(OUTPUT_FILE, JSON.pretty_generate({ tables: tables }))
    puts "schema_map.json generated successfully."
  end

  private

  # Tabloları yakala
  def extract_tables(sql)
    tables = {}

    # Daha esnek regex: IF NOT EXISTS, tırnaklı, multiline
    sql.scan(/CREATE TABLE\s+(?:IF NOT EXISTS\s+)?(?:"?public"?\.)?"?(\w+)"?\s*\((.*?)\);/m) do |table_name, body|
      columns = body.scan(/^\s*"?(\w+)"?\s+/).flatten
      tables[table_name] = {
        columns: columns,
        foreign_keys: []
      }
    end

    tables
  end

  # Foreign keyleri yakala
  def extract_foreign_keys(sql)
    sql.scan(
      /ALTER TABLE ONLY\s+(?:"?public"?\.)?"?(\w+)"?.*?FOREIGN KEY \((\w+)\) REFERENCES\s+(?:"?public"?\.)?"?(\w+)"?\((\w+)\)/m
    ).map do |from_table, column, to_table, to_column|
      {
        from_table: from_table,
        column: column,
        to_table: to_table,
        to_column: to_column
      }
    end
  end

  # FK’leri tabloların içine ekle
  def attach_foreign_keys(tables, foreign_keys)
    foreign_keys.each do |fk|
      next unless tables[fk[:from_table]]

      tables[fk[:from_table]][:foreign_keys] << {
        column: fk[:column],
        references_table: fk[:to_table],
        references_column: fk[:to_column]
      }
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  SchemaMapper.run
end