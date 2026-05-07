#include <mysql.h>

#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>

namespace {
struct ClusterConfig {
  std::string host;
  unsigned int port;
  std::string user;
  std::string password;
  std::string database;
};

ClusterConfig load_config() {
  auto getenv_or = [](const char* key, const char* fallback) {
    const char* value = std::getenv(key);
    return std::string(value == nullptr || std::string(value).empty() ? fallback : value);
  };

  return {
      getenv_or("DB_HOST", "127.0.0.1"),
      static_cast<unsigned int>(std::stoul(getenv_or("DB_PORT", "3306"))),
      getenv_or("DB_USER", "cluster_app"),
      getenv_or("DB_PASSWORD", "ClusterApp123!"),
      getenv_or("DB_NAME", "cluster_poc"),
  };
}

class MysqlConnection {
 public:
  explicit MysqlConnection(const ClusterConfig& config) {
    handle_ = mysql_init(nullptr);
    if (handle_ == nullptr) {
      throw std::runtime_error("Failed to initialize MYSQL.");
    }

    if (mysql_real_connect(
            handle_,
            config.host.c_str(),
            config.user.c_str(),
            config.password.c_str(),
            config.database.c_str(),
            config.port,
            nullptr,
            CLIENT_MULTI_STATEMENTS) == nullptr) {
      throw std::runtime_error(mysql_error(handle_));
    }
  }

  ~MysqlConnection() {
    if (handle_ != nullptr) {
      mysql_close(handle_);
    }
  }

  MYSQL* get() const { return handle_; }

 private:
  MYSQL* handle_ = nullptr;
};

void exec_or_throw(MYSQL* handle, const std::string& sql) {
  if (mysql_query(handle, sql.c_str()) != 0) {
    throw std::runtime_error(mysql_error(handle));
  }

  while (mysql_next_result(handle) == 0) {
    MYSQL_RES* extra_result = mysql_store_result(handle);
    if (extra_result != nullptr) {
      mysql_free_result(extra_result);
    }
  }
}

std::string load_file(const std::filesystem::path& path) {
  std::ifstream input(path);
  if (!input.is_open()) {
    throw std::runtime_error("Failed to open migration: " + path.string());
  }

  std::ostringstream buffer;
  buffer << input.rdbuf();
  return buffer.str();
}

void validate_ndb_engine(MYSQL* handle) {
  exec_or_throw(handle, "SHOW ENGINES");
  MYSQL_RES* result = mysql_store_result(handle);
  if (result == nullptr) {
    throw std::runtime_error("Failed to read MySQL engines.");
  }

  bool found = false;
  MYSQL_ROW row;
  while ((row = mysql_fetch_row(result)) != nullptr) {
    if (row[0] != nullptr && std::string(row[0]) == "ndbcluster" && row[1] != nullptr &&
        std::string(row[1]) != "NO") {
      found = true;
      break;
    }
  }

  mysql_free_result(result);

  if (!found) {
    throw std::runtime_error("Engine NDBCLUSTER is not available.");
  }
}

void run_migrations(MYSQL* handle, const std::filesystem::path& base_dir) {
  std::cout << "Running C++ migrations." << std::endl;
  exec_or_throw(
      handle,
      "CREATE TABLE IF NOT EXISTS schema_migrations_cpp (version VARCHAR(255) PRIMARY KEY)");

  const auto migration_name = std::string("001_create_cpp_cluster_messages.sql");
  const auto check_sql =
      "SELECT COUNT(*) FROM schema_migrations_cpp WHERE version = '" + migration_name + "'";
  exec_or_throw(handle, check_sql);
  MYSQL_RES* result = mysql_store_result(handle);
  MYSQL_ROW row = mysql_fetch_row(result);
  const bool already_applied = row != nullptr && row[0] != nullptr && std::string(row[0]) != "0";
  mysql_free_result(result);

  if (already_applied) {
    std::cout << "Migration ja aplicada: " << migration_name << std::endl;
    return;
  }

  const auto sql = load_file(base_dir / "migrations" / migration_name);
  exec_or_throw(handle, sql);
  exec_or_throw(
      handle,
      "INSERT INTO schema_migrations_cpp (version) VALUES ('" + migration_name + "')");
}

void run_raw_checks(MYSQL* handle) {
  std::cout << "Running raw C++ CRUD." << std::endl;
  exec_or_throw(handle, "DELETE FROM cpp_cluster_messages");

  const auto content = std::string("raw c++");
  exec_or_throw(
      handle,
      "INSERT INTO cpp_cluster_messages (content) VALUES ('" + content + "')");
  const auto inserted_id = mysql_insert_id(handle);

  exec_or_throw(
      handle,
      "SELECT content FROM cpp_cluster_messages WHERE id = " + std::to_string(inserted_id));
  MYSQL_RES* result = mysql_store_result(handle);
  MYSQL_ROW row = mysql_fetch_row(result);
  if (row == nullptr || row[0] == nullptr || content != row[0]) {
    mysql_free_result(result);
    throw std::runtime_error("Failed to read the record inserted via raw C++.");
  }
  mysql_free_result(result);

  exec_or_throw(
      handle,
      "DELETE FROM cpp_cluster_messages WHERE id = " + std::to_string(inserted_id));
  std::cout << "Raw CRUD validated. id=" << inserted_id << std::endl;
}

class ClusterMessageRepository {
 public:
  explicit ClusterMessageRepository(MYSQL* handle) : handle_(handle) {}

  unsigned long long create(const std::string& content) {
    exec_or_throw(handle_, "INSERT INTO cpp_cluster_messages (content) VALUES ('" + content + "')");
    return mysql_insert_id(handle_);
  }

  std::string find_content(unsigned long long id) {
    exec_or_throw(handle_, "SELECT content FROM cpp_cluster_messages WHERE id = " + std::to_string(id));
    MYSQL_RES* result = mysql_store_result(handle_);
    MYSQL_ROW row = mysql_fetch_row(result);
    const auto content = row != nullptr && row[0] != nullptr ? std::string(row[0]) : std::string();
    mysql_free_result(result);
    return content;
  }

  void remove(unsigned long long id) {
    exec_or_throw(handle_, "DELETE FROM cpp_cluster_messages WHERE id = " + std::to_string(id));
  }

 private:
  MYSQL* handle_;
};

void run_repository_checks(MYSQL* handle) {
  std::cout << "Running CRUD through the C++ repository." << std::endl;
  exec_or_throw(handle, "DELETE FROM cpp_cluster_messages");

  ClusterMessageRepository repository(handle);
  const auto content = std::string("repository c++");
  const auto id = repository.create(content);
  const auto loaded = repository.find_content(id);
  if (loaded != content) {
    throw std::runtime_error("Failed to read the record through the C++ repository.");
  }

  repository.remove(id);
  const auto deleted = repository.find_content(id);
  if (!deleted.empty()) {
    throw std::runtime_error("Failed to delete the record through the C++ repository.");
  }

  std::cout << "Repository validated. id=" << id << std::endl;
}
}  // namespace

int main(int argc, char** argv) {
  try {
    const auto config = load_config();
    const auto executable_path = std::filesystem::absolute(argv[0]).parent_path().parent_path();
    MysqlConnection connection(config);

    std::cout << "Starting C/C++ PoC against " << config.host << ":" << config.port << "/"
              << config.database << std::endl;

    validate_ndb_engine(connection.get());
    run_migrations(connection.get(), executable_path);
    run_raw_checks(connection.get());
    run_repository_checks(connection.get());

    std::cout << "C/C++ PoC validated successfully." << std::endl;
    return 0;
  } catch (const std::exception& error) {
    std::cerr << "C/C++ PoC failed: " << error.what() << std::endl;
    return 1;
  }
}
