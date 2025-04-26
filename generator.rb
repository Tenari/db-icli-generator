require 'toml-rb'

if ARGV[0].nil?
  puts "you gotta tell me what config file to use, dipshit"
  exit
end

conf = TomlRB.load_file(ARGV[0])

sql = ""

conf.each do |table_name, details|
  foreign_key_sql = []
  column_sql = "  id INTEGER PRIMARY KEY AUTOINCREMENT,\n"
  details.each do |col, settings|
    column_sql += "  #{col} #{settings["type"].upcase}"
    if settings["not_null"]
      column_sql += " NOT NULL"
    end
    if settings["default"]
      column_sql += " DEFAULT #{settings["default"]}"
    end
    if settings["check"]
      column_sql += " CHECK (#{col} IN (#{settings["check"].map {|i| i.inspect}.join(", ")}))"
    end
    column_sql += ",\n"

    if settings['foreign']
      foreign_key_sql.push("  FOREIGN KEY (#{col}) REFERENCES #{settings['foreign']} (id)")
    end
  end
  column_sql += "  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,\n  created_at TEXT DEFAULT CURRENT_TIMESTAMP,\n"
  sql += "CREATE TABLE IF NOT EXISTS #{table_name} (
#{column_sql}#{foreign_key_sql.join(",\n")}
);\n"
end

puts sql
