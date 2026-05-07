class CreateRubyClusterMessages < ActiveRecord::Migration[7.1]
  def up
    execute <<~SQL
      CREATE TABLE IF NOT EXISTS ruby_cluster_messages (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        content VARCHAR(255) NOT NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (id)
      ) ENGINE=NDBCLUSTER DEFAULT CHARSET=utf8mb4
    SQL
  end

  def down
    execute "DROP TABLE IF EXISTS ruby_cluster_messages"
  end
end
