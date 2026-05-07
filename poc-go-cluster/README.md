# PoC Go + MySQL Cluster

Esta PoC valida:

1. migration com `goose`
2. CRUD com `database/sql`
3. CRUD com `GORM`

## Uso

```bash
cd poc-go-cluster
bash ./run-poc-go.sh
```

## Variaveis

```bash
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=cluster_app
DB_PASSWORD=ClusterApp123!
DB_NAME=cluster_poc
```
