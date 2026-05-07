# C# PoC + MySQL Cluster

This PoC validates:

1. access to a database already provisioned in the cluster
2. migrations with a versioned SQL-file runner
3. raw CRUD with `Dapper` + `MySqlConnector`
4. ORM CRUD with `Entity Framework Core`

## Usage

With the cluster running and a database/user already created:

```bash
cd poc-csharp-cluster
bash ./run-poc-csharp.sh
```

## Variables

```bash
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=cluster_app
DB_PASSWORD=ClusterApp123!
DB_NAME=cluster_poc
```
