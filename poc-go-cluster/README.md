# Go PoC + MySQL Cluster

This PoC validates:

1. migrations with `goose`
2. raw CRUD with `database/sql`
3. ORM CRUD with `GORM`

## Usage

```bash
cd poc-go-cluster
bash ./run-poc-go.sh
```

## Variables

```bash
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=cluster_app
DB_PASSWORD=ClusterApp123!
DB_NAME=cluster_poc
```
