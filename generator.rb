require 'toml-rb'

if ARGV[0].nil?
  puts "you gotta tell me what config file to use, dipshit"
  exit
end

conf = TomlRB.load_file(ARGV[0])

def make_create_table_sql(conf)
  sql = ""
  conf.each do |table_name, details|
    foreign_key_sql = []
    column_sql = "  id INTEGER PRIMARY KEY AUTOINCREMENT"
    details.each do |col, settings|
      column_sql += ",\n"
      column_sql += "  #{col} #{settings["type"].upcase}"
      if settings["not_null"]
        column_sql += " NOT NULL"
      end
      if settings["default"]
        column_sql += " DEFAULT #{settings["default"]}"
      end
      if settings["check"]
        column_sql += " CHECK (#{col} IN (#{settings["check"].map {|i| i.inspect.gsub('"',"'")}.join(", ")}))"
      end

      if settings['foreign']
        foreign_key_sql.push("  FOREIGN KEY (#{col}) REFERENCES #{settings['foreign']} (id)")
      end
    end
    column_sql += ",\n  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,\n  created_at TEXT DEFAULT CURRENT_TIMESTAMP"
    sql += "CREATE TABLE IF NOT EXISTS #{table_name} (
#{column_sql}#{foreign_key_sql.count > 0 ? ",\n" : ""}#{foreign_key_sql.join(",\n")}
);\n"
  end
  sql
end

def sql_type_to_zig_type(type)
  if type == "text"
    "[]const u8"
  elsif type == "integer"
    "i64"
  elsif type == "real"
    "f64"
  end
end

# create the zig types.zig file
def make_zig_types(conf)
  ztypes = ""
  nouns = []
  conf.each do |table_name, details|
    struct_name = table_name[0..-2].capitalize
    nouns.push(struct_name.downcase)
    enums = ""
    fields = "  id: i64,\n"
    details.each do |col, settings|
      zig_type = sql_type_to_zig_type(settings["type"].downcase)
      if settings["check"]
        zig_type = "#{struct_name}#{col.capitalize}"
        enums += "pub const #{zig_type} = enum { #{settings['check'].map {|opt| opt }.join(', ')} };\n"
      end
      nullable = settings["not_null"] ? "" : (settings["check"] ? "" : "?")
      fields += "  #{col}: #{nullable}#{zig_type},\n"
    end
    fields += "  updated_at: []const u8,\n  created_at: []const u8,\n"
    ztypes += "#{enums}pub const #{struct_name} = struct {
#{fields}};\n\n"
  end
    ztypes += "pub const Noun = enum {
  #{nouns.join(', ')},

    pub fn toType(self: Noun) type {
        return switch (self) {
            #{nouns.map {|n| "#{n} => #{n.capitalize}"}.join(",\n            ")}
        }
    }
};
\n"
  ztypes
end

# actually create the project
project_name = ARGV[0].gsub(".toml","")
# remove previous version of the project unless they passed the `-keep` flag
`rm -rf #{project_name}/` unless ARGV[1] == '-keep'
`mkdir #{project_name}`

# create the sql file definition
File.open("#{project_name}/#{project_name}.sql", 'w') { |file| file.write(make_create_table_sql(conf)) }
# create the zig src dir
`mkdir #{project_name}/src`
# create the zig src/types.zig file
File.open("#{project_name}/src/types.zig", 'w') { |file| file.write(make_zig_types(conf)) }
# create the zig src/main.zig file
