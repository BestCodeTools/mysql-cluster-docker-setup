# MySQL Cluster with Docker

This repository packages a simple **MySQL Cluster** setup with:

- `1` management node
- `2` data nodes
- `1` MySQL server node
- Bash scripts to create databases and users
- `1` Node.js PoC for `sequelize` + `knex`
- `1` C# PoC for raw queries + EF Core
- `1` Java PoC for JDBC + Hibernate
- `1` C/C++ PoC for Connector/C
- `1` Go PoC for `database/sql` + GORM
- `1` Python PoC for SQLAlchemy Core + ORM
- `1` Ruby PoC for raw queries + ActiveRecord

The goal is to bring the cluster up predictably with Bash scripts, ensure every container reaches `healthy`, and validate application access from multiple languages.

## Structure

- [start-mysql-cluster.sh](X:/DEV/docker/mysql-cluster/start-mysql-cluster.sh): starts the cluster, waits for readiness, and creates a remote application user
- [stop-mysql-cluster.sh](X:/DEV/docker/mysql-cluster/stop-mysql-cluster.sh): removes cluster containers and, by default, removes the Docker network
- [create-cluster-database.sh](X:/DEV/docker/mysql-cluster/create-cluster-database.sh): creates a database in the SQL node
- [create-cluster-user.sh](X:/DEV/docker/mysql-cluster/create-cluster-user.sh): creates a user and grants in the SQL node
- [.github/workflows/mysql-cluster-validation.yml](X:/DEV/docker/mysql-cluster/.github/workflows/mysql-cluster-validation.yml): CI workflow for cluster provisioning and multi-language validation
- [GUIDELINES.md](X:/DEV/docker/mysql-cluster/GUIDELINES.md): source guideline derived from the `mysql/mysql-cluster` image docs
- [poc-node-cluster](X:/DEV/docker/mysql-cluster/poc-node-cluster/README.md)
- [poc-csharp-cluster](X:/DEV/docker/mysql-cluster/poc-csharp-cluster/README.md)
- [poc-java-cluster](X:/DEV/docker/mysql-cluster/poc-java-cluster/README.md)
- [poc-cpp-cluster](X:/DEV/docker/mysql-cluster/poc-cpp-cluster/README.md)
- [poc-go-cluster](X:/DEV/docker/mysql-cluster/poc-go-cluster/README.md)
- [poc-python-cluster](X:/DEV/docker/mysql-cluster/poc-python-cluster/README.md)
- [poc-ruby-cluster](X:/DEV/docker/mysql-cluster/poc-ruby-cluster/README.md)

## Requirements

- Docker installed and working
- Bash available
  - Example: WSL Ubuntu, Git Bash, or Linux
- Port `3306` available if you want to publish MySQL to the host

## Start the cluster

From the repository root:

```bash
bash ./start-mysql-cluster.sh
```

The script does the following:

1. Ensures the `mysql/mysql-cluster` image is available locally
2. Stops the `fivem_mysql` container if needed to free port `3306`
3. Removes old cluster containers if they exist
4. Creates the `cluster` Docker network
5. Starts `management1`
6. Starts `ndb1`
7. Starts `ndb2`
8. Starts `mysql1`
9. Waits for all containers to become `healthy`
10. Creates a remote application user
11. Prints examples for the database and user helper scripts
12. Generates a cluster config file that matches the selected subnet and node IPs

## Default resources

By default the cluster uses:

- Docker network: `cluster`
- Docker subnet: `10.66.0.0/24`
- Management node: `management1` at `10.66.0.2`
- Data node 1: `ndb1` at `10.66.0.3`
- Data node 2: `ndb2` at `10.66.0.4`
- MySQL server: `mysql1` at `10.66.0.10`
- Published host port: `3306`

## Default credentials

The startup script configures:

- `root`: `ClusterRoot123!`
- application user: `cluster_app`
- application password: `ClusterApp123!`
- authentication plugin: `mysql_native_password`

Important note:

`root` works well for administration inside the container, but for host-side application access the recommended account is `cluster_app`, which the script provisions automatically.

## Useful environment variables

You can override the defaults when starting the cluster:

```bash
MYSQL_ROOT_PASSWORD='AnotherRootPass123!'
APP_DB_USER='app_user'
APP_DB_PASSWORD='AppPass123!'
bash ./start-mysql-cluster.sh
```

Supported startup variables:

- `NETWORK_NAME`
- `SUBNET_CIDR`
- `IMAGE_NAME`
- `RUNTIME_DIR`
- `MANAGER_NAME`
- `MANAGER_IP`
- `NDB1_NAME`
- `NDB1_IP`
- `NDB2_NAME`
- `NDB2_IP`
- `MYSQL_NAME`
- `MYSQL_IP`
- `MYSQL_PORT`
- `PUBLISH_MYSQL_PORT`
- `STOP_FIVEM_MYSQL`
- `APP_DB_AUTH_PLUGIN`

Example without publishing port `3306`:

```bash
PUBLISH_MYSQL_PORT=false bash ./start-mysql-cluster.sh
```

Example using an explicit safe subnet and port:

```bash
SUBNET_CIDR=10.66.0.0/24 \
MANAGER_IP=10.66.0.2 \
NDB1_IP=10.66.0.3 \
NDB2_IP=10.66.0.4 \
MYSQL_IP=10.66.0.10 \
MYSQL_PORT=3307 \
bash ./start-mysql-cluster.sh
```

The startup script now generates a `mysql-cluster.cnf` file automatically inside `.cluster-runtime/` so the manager configuration always matches the chosen subnet and node IPs.

## Create databases and users

This repository includes two helper scripts:

- [create-cluster-database.sh](X:/DEV/docker/mysql-cluster/create-cluster-database.sh)
- [create-cluster-user.sh](X:/DEV/docker/mysql-cluster/create-cluster-user.sh)

### Why commands run on `mysql1`

SQL commands are executed directly in `mysql1`, which is the **MySQL server node** for this cluster.

That is the correct behavior here because:

- `management1` is for cluster management, not application SQL
- `ndb1` and `ndb2` are data nodes, not SQL endpoints
- `mysql1` is the node that accepts MySQL connections and exposes `NDBCLUSTER`

So for databases, users, grants, and tables, `mysql1` is the right target.

### Create a database

Basic usage:

```bash
bash ./create-cluster-database.sh app_db
```

Custom charset/collation example:

```bash
DB_CHARSET=utf8mb4 DB_COLLATION=utf8mb4_general_ci bash ./create-cluster-database.sh logs_db
```

Supported variables:

- `MYSQL_NAME`
- `MYSQL_ROOT_PASSWORD`
- `DB_CHARSET`
- `DB_COLLATION`

### Create a user with grants

Basic usage:

```bash
bash ./create-cluster-user.sh app_user 'Password123!' app_db
```

This command:

- creates `app_user`
- sets the provided password
- grants `ALL PRIVILEGES` on `app_db.*`

Restrict host example:

```bash
TARGET_HOST=127.0.0.1 bash ./create-cluster-user.sh local_user 'Password123!' app_db
```

Specific privileges example:

```bash
GRANT_PRIVILEGES='SELECT,INSERT,UPDATE,DELETE' bash ./create-cluster-user.sh api_user 'Password123!' app_db
```

Supported variables:

- `MYSQL_NAME`
- `MYSQL_ROOT_PASSWORD`
- `TARGET_HOST`
- `GRANT_PRIVILEGES`
- `AUTH_PLUGIN`

### Recommended provisioning flow

```bash
bash ./create-cluster-database.sh my_app
bash ./create-cluster-user.sh my_app_user 'MyPassword123!' my_app
```

Then your application can point to:

- host: `127.0.0.1`
- port: `3306`
- database: `my_app`
- user: `my_app_user`
- password: the configured password

By default the script uses `mysql_native_password`, which improves compatibility across Node.js, .NET, Java, and native client libraries.

## Stop and remove the cluster

From the repository root:

```bash
bash ./stop-mysql-cluster.sh
```

The script removes:

1. `mysql1`
2. `ndb2`
3. `ndb1`
4. `management1`
5. the `cluster` network

To keep the network:

```bash
REMOVE_NETWORK=false bash ./stop-mysql-cluster.sh
```

## Node.js PoC

The Node.js PoC lives in [poc-node-cluster](X:/DEV/docker/mysql-cluster/poc-node-cluster/README.md).

It validates:

1. Node.js access through `sequelize`
2. table creation through `knex` migration
3. confirmation that the table uses `ENGINE=NDBCLUSTER`
4. CRUD with raw queries
5. CRUD with `sequelize`

Windows:

```bash
cd poc-node-cluster
npm.cmd install
npm.cmd run test:all
```

Linux / WSL:

```bash
cd poc-node-cluster
npm install
npm run test:all
```

## Other PoCs

### C#

[poc-csharp-cluster](X:/DEV/docker/mysql-cluster/poc-csharp-cluster/README.md)

- SQL-file migration runner
- raw CRUD with `Dapper` + `MySqlConnector`
- ORM CRUD with `Entity Framework Core`

### Java

[poc-java-cluster](X:/DEV/docker/mysql-cluster/poc-java-cluster/README.md)

- migrations with `Flyway`
- raw CRUD with `JDBC`
- ORM CRUD with `Hibernate`

### C/C++

[poc-cpp-cluster](X:/DEV/docker/mysql-cluster/poc-cpp-cluster/README.md)

- SQL-file migration runner
- raw CRUD with Connector/C
- CRUD through a small C++ repository

### Go

[poc-go-cluster](X:/DEV/docker/mysql-cluster/poc-go-cluster/README.md)

- migrations with `goose`
- raw CRUD with `database/sql`
- ORM CRUD with `GORM`

### Python

[poc-python-cluster](X:/DEV/docker/mysql-cluster/poc-python-cluster/README.md)

- migrations with `Alembic`
- raw CRUD with SQLAlchemy Core
- ORM CRUD with SQLAlchemy ORM

### Ruby

[poc-ruby-cluster](X:/DEV/docker/mysql-cluster/poc-ruby-cluster/README.md)

- migrations with `ActiveRecord`
- raw CRUD with direct SQL
- ORM CRUD with `ActiveRecord`

## GitHub Actions validation

The workflow [mysql-cluster-validation.yml](X:/DEV/docker/mysql-cluster/.github/workflows/mysql-cluster-validation.yml) validates the full setup in CI.

It:

1. starts the cluster with `start-mysql-cluster.sh`
2. creates a validation database
3. creates a validation user
4. runs each PoC inside its own language-specific Docker image
5. validates migrations and CRUD for every implemented language
6. always tears the cluster down at the end

Languages covered in CI:

- Node.js
- C#
- Java
- C/C++
- Go
- Python
- Ruby

Container images used in CI include:

- `node:20-bookworm`
- `mcr.microsoft.com/dotnet/sdk:8.0`
- `maven:3.9.9-eclipse-temurin-17`
- `gcc:14-bookworm`
- `golang:1.25-bookworm`
- `python:3.11-bookworm`
- `ruby:3.3-bookworm`

This keeps CI closer to a real multi-language runtime environment without depending on toolchains installed directly on the runner.

The workflow runs on:

- `push` to `main`
- `push` to `master`
- `pull_request`
- manual `workflow_dispatch`

## Manual cluster checks

### Container status

```bash
docker ps
```

You should see `management1`, `ndb1`, `ndb2`, and `mysql1` with `healthy` status.

### Management client

```bash
docker run --rm --net cluster mysql/mysql-cluster ndb_mgm -c 10.66.0.2 -e show
```

You should see:

- `2` `ndbd(NDB)` nodes
- `1` `ndb_mgmd(MGM)` node
- `1` `mysqld(API)` node

## Common issues

### Only `mysql1` becomes healthy

This repository specifically addresses that case by:

- respecting the strict startup order
- waiting for each container before starting the next
- using different health checks for the manager, data nodes, and MySQL server

### `Host '_gateway' is not allowed to connect`

This happens when trying to connect from the host with `root`. The scripts solve it by creating `cluster_app@'%'`.

### Port `3306` is already in use

If another MySQL container is running, port publishing can fail. The startup script attempts to stop `fivem_mysql` by default to free that port.

If you do not want to publish `3306`:

```bash
PUBLISH_MYSQL_PORT=false bash ./start-mysql-cluster.sh
```

### Start clean

```bash
bash ./stop-mysql-cluster.sh
bash ./start-mysql-cluster.sh
```

### Add more databases and users later

```bash
bash ./create-cluster-database.sh another_db
bash ./create-cluster-user.sh another_user 'AnotherPassword123!' another_db
```

## Notes

- This setup is intended for local development and PoC work
- The scripts are idempotent enough to make reruns easy
- Every PoC creates tables explicitly with `ENGINE=NDBCLUSTER`
- The cluster was validated locally with all four main containers in `healthy`
- Database and user helper scripts were validated locally against `mysql1`
- The C# PoC was executed and validated locally on this host
- The Go and Python PoCs were executed and validated locally on this host
- The Java, C/C++, and Ruby PoCs were structured for CI validation, but were not executed locally here because this host does not have `mvn`, `g++`, or `ruby`

## References

- [GUIDELINES.md](X:/DEV/docker/mysql-cluster/GUIDELINES.md)
- [MySQL Cluster image on Docker Hub](https://hub.docker.com/r/mysql/mysql-cluster)
