require "active_record"
require "mysql2"
require "logger"

require_relative "./config"

ActiveRecord::Base.establish_connection(
  adapter: "mysql2",
  host: CONFIG[:host],
  port: CONFIG[:port],
  username: CONFIG[:user],
  password: CONFIG[:password],
  database: CONFIG[:database],
)

class RubyClusterMessage < ActiveRecord::Base
  self.table_name = "ruby_cluster_messages"
end

def validate_ndb_engine
  rows = ActiveRecord::Base.connection.exec_query("SHOW ENGINES")
  row = rows.find { |item| item["Engine"].to_s.casecmp("NDBCLUSTER").zero? }
  raise "Engine NDBCLUSTER is not available." if row.nil? || row["Support"].to_s.casecmp("NO").zero?

  puts "Engine NDBCLUSTER available (#{row['Support']})."
end

def run_migrations
  puts "Running migration with ActiveRecord."
  migrations_path = File.join(__dir__, "db", "migrate")
  context = ActiveRecord::MigrationContext.new(migrations_path, ActiveRecord::SchemaMigration)
  context.up
end

def run_raw_checks
  puts "Running CRUD with raw queries."
  connection = ActiveRecord::Base.connection
  connection.execute("DELETE FROM ruby_cluster_messages")

  content = "raw ruby"
  quoted_content = connection.quote(content)
  connection.execute("INSERT INTO ruby_cluster_messages (content) VALUES (#{quoted_content})")
  inserted_id = connection.select_value("SELECT LAST_INSERT_ID()").to_i

  loaded = connection.select_value(
    ActiveRecord::Base.send(:sanitize_sql_array, ["SELECT content FROM ruby_cluster_messages WHERE id = ?", inserted_id]),
  )
  raise "Failed to read the record inserted via raw query." unless loaded == content

  connection.execute(
    ActiveRecord::Base.send(:sanitize_sql_array, ["DELETE FROM ruby_cluster_messages WHERE id = ?", inserted_id]),
  )
  count = connection.select_value(
    ActiveRecord::Base.send(:sanitize_sql_array, ["SELECT COUNT(*) FROM ruby_cluster_messages WHERE id = ?", inserted_id]),
  ).to_i
  raise "Failed to delete the record via raw query." unless count.zero?

  puts "Raw query validated. id=#{inserted_id}"
end

def run_orm_checks
  puts "Running CRUD with ActiveRecord."
  RubyClusterMessage.delete_all

  content = "activerecord ruby"
  message = RubyClusterMessage.create!(content: content)
  loaded = RubyClusterMessage.find(message.id)
  raise "Failed to read the record inserted via ActiveRecord." unless loaded.content == content

  loaded.destroy!
  deleted = RubyClusterMessage.find_by(id: message.id)
  raise "Failed to delete the record via ActiveRecord." unless deleted.nil?

  puts "ActiveRecord validated. id=#{message.id}"
end

puts "Starting Ruby PoC."
validate_ndb_engine
run_migrations
run_raw_checks
run_orm_checks
puts "Ruby PoC validated successfully."
