# Python PoC + MySQL Cluster

This PoC validates:

1. migrations with `Alembic`
2. raw CRUD with SQLAlchemy Core
3. ORM CRUD with SQLAlchemy ORM

## Usage

```bash
cd poc-python-cluster
bash ./run-poc-python.sh
```

## Variables

```bash
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=cluster_app
DB_PASSWORD=ClusterApp123!
DB_NAME=cluster_poc
```
