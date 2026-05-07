# Ruby PoC + MySQL Cluster

This PoC validates:

1. migrations with `ActiveRecord`
2. raw CRUD with direct SQL
3. ORM CRUD with `ActiveRecord`

## Usage

```bash
cd poc-ruby-cluster
bash ./run-poc-ruby.sh
```

## Variables

```bash
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=cluster_app
DB_PASSWORD=ClusterApp123!
DB_NAME=cluster_poc
```
