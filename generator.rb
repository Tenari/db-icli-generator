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

# create the sql file definition
File.open(ARGV[0].gsub(".toml", ".sql"), 'w') { |file| file.write(sql) }

# create the zig types.zig file
def sql_type_to_zig_type(type)
  if type == "text"
    "[]const u8"
  elsif type == "integer"
    "i64"
  elsif type == "real"
    "f64"
  end
end

ztypes = ""
conf.each do |table_name, details|
  struct_name = table_name[0..-2].capitalize
  enums = ""
  fields = "  id: i64,\n"
  details.each do |col, settings|
    zig_type = sql_type_to_zig_type(settings["type"].downcase)
    if settings["check"]
      zig_type = "#{struct_name}#{col.capitalize}"
      enums += "const #{zig_type} = enum { #{settings['check'].map {|opt| opt }.join(', ')} };\n"
    end
    nullable = settings["not_null"] ? "" : (settings["check"] ? "" : "?")
    fields += "  #{col}: #{nullable}#{zig_type},\n"
  end
  fields += "  updated_at: []const u8,\n  created_at: []const u8,\n"
  ztypes += "#{enums}const #{struct_name} = struct {
#{fields}};\n\n"
end

puts ztypes
