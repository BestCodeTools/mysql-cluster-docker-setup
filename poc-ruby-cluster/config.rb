def env_or_default(key, fallback)
  value = ENV[key]
  value.nil? || value.empty? ? fallback : value
end

CONFIG = {
  host: env_or_default("DB_HOST", "127.0.0.1"),
  port: Integer(env_or_default("DB_PORT", "3306")),
  user: env_or_default("DB_USER", "cluster_app"),
  password: env_or_default("DB_PASSWORD", "ClusterApp123!"),
  database: env_or_default("DB_NAME", "cluster_poc"),
}.freeze
