# PoC C# + MySQL Cluster

Esta PoC valida:

1. conexao com um database ja provisionado no cluster
2. migration com runner proprio baseado em arquivos SQL versionados
3. CRUD com raw query usando `Dapper` + `MySqlConnector`
4. CRUD com `Entity Framework Core`

## Uso

Com o cluster rodando e um database/usuario ja criados:

```bash
cd poc-csharp-cluster
bash ./run-poc-csharp.sh
```

## Variaveis

```bash
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=cluster_app
DB_PASSWORD=ClusterApp123!
DB_NAME=cluster_poc
```
