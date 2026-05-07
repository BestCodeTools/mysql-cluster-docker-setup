# PoC C/C++ + MySQL Cluster

Esta PoC valida:

1. conexao com database ja provisionado
2. migration propria baseada em arquivos SQL versionados
3. CRUD com a API nativa do MySQL/MariaDB Connector/C
4. um pequeno repository C++ em cima da API nativa

## Uso

Em ambiente Linux ou WSL com `g++` e Connector/C instalados:

```bash
cd poc-cpp-cluster
bash ./run-poc-cpp.sh
```

## Dependencias esperadas

- `g++`
- `pkg-config`
- `libmariadb-dev` ou `default-libmysqlclient-dev`

## Variaveis

```bash
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=cluster_app
DB_PASSWORD=ClusterApp123!
DB_NAME=cluster_poc
```
