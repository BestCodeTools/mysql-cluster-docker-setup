# C/C++ PoC + MySQL Cluster

This PoC validates:

1. access to an already provisioned database
2. a custom migration runner based on versioned SQL files
3. raw CRUD with the MySQL/MariaDB Connector/C API
4. CRUD through a small C++ repository abstraction

## Usage

On Linux or WSL with `g++` and Connector/C installed:

```bash
cd poc-cpp-cluster
bash ./run-poc-cpp.sh
```

## Expected dependencies

- `g++`
- `pkg-config`
- `libmariadb-dev` or `default-libmysqlclient-dev`

## Variables

```bash
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=cluster_app
DB_PASSWORD=ClusterApp123!
DB_NAME=cluster_poc
```
