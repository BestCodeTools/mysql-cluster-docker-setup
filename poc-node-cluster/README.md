# PoC Node.js + MySQL Cluster

Esta pasta valida dois cenarios simples contra o cluster:

1. Uma aplicacao Node.js conectando com `sequelize`.
2. Uma migration com `knex` criando tabela com `ENGINE=NDBCLUSTER`.

## Uso

Com o cluster ja rodando e a porta `3306` publicada:

```bash
cd poc-node-cluster
npm install
npm run test:all
```

## Variaveis opcionais

```bash
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=cluster_app
DB_PASSWORD=ClusterApp123!
DB_NAME=cluster_poc
```
