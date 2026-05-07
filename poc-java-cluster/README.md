# PoC Java + MySQL Cluster

Esta PoC valida:

1. conexao com database ja provisionado
2. migration com `Flyway`
3. CRUD com JDBC
4. CRUD com `Hibernate`

## Uso

```bash
cd poc-java-cluster
bash ./run-poc-java.sh
```

## Variaveis

```bash
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=cluster_app
DB_PASSWORD=ClusterApp123!
DB_NAME=cluster_poc
```
