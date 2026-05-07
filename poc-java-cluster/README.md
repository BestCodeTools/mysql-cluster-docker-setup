# Java PoC + MySQL Cluster

This PoC validates:

1. access to an already provisioned database
2. migrations with `Flyway`
3. raw CRUD with `JDBC`
4. ORM CRUD with `Hibernate`

## Usage

```bash
cd poc-java-cluster
bash ./run-poc-java.sh
```

## Variables

```bash
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=cluster_app
DB_PASSWORD=ClusterApp123!
DB_NAME=cluster_poc
```
