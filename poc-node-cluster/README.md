# PoC Node.js + MySQL Cluster

Esta pasta valida os seguintes cenarios contra o cluster:

1. Uma aplicacao Node.js conectando com `sequelize`.
2. Uma migration com `knex` criando tabela com `ENGINE=NDBCLUSTER`.
3. Operacoes de insert, select e delete com raw query.
4. Operacoes de insert, select e delete com `sequelize`.

## Uso

Com o cluster ja rodando e a porta `3306` publicada:

```bash
cd poc-node-cluster
npm install
npm run test:all
```

Se quiser validar com um usuario/banco especificos ja provisionados pelos scripts da raiz:

```bash
DB_HOST=127.0.0.1 \
DB_PORT=3306 \
DB_USER=gha_cluster_user \
DB_PASSWORD='GhaClusterPass123!' \
DB_NAME=gha_cluster_validation \
npm run test:all
```

## O fluxo executado

O runner `test:all` faz:

1. validacao basica do acesso e do engine `NDBCLUSTER`
2. migration via `knex`
3. checagem da tabela com `sequelize`
4. testes CRUD com raw query
5. testes CRUD com `sequelize`
6. verificacao final da engine da tabela

## Variaveis opcionais

```bash
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=cluster_app
DB_PASSWORD=ClusterApp123!
DB_NAME=cluster_poc
```
