# Node.js PoC + MySQL Cluster

This folder validates:

1. a Node.js application connecting through `sequelize`
2. a `knex` migration creating a table with `ENGINE=NDBCLUSTER`
3. insert, select, and delete operations with raw queries
4. insert, select, and delete operations with `sequelize`

## Usage

With the cluster already running and port `3306` published:

```bash
cd poc-node-cluster
npm install
npm run test:all
```

To validate with a specific database and user provisioned from the root scripts:

```bash
DB_HOST=127.0.0.1 \
DB_PORT=3306 \
DB_USER=gha_cluster_user \
DB_PASSWORD='GhaClusterPass123!' \
DB_NAME=gha_cluster_validation \
npm run test:all
```

## Flow

`test:all` runs:

1. basic database and `NDBCLUSTER` engine checks
2. migration execution through `knex`
3. table verification through `sequelize`
4. raw query CRUD checks
5. `sequelize` CRUD checks
6. final table engine verification

## Optional variables

```bash
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=cluster_app
DB_PASSWORD=ClusterApp123!
DB_NAME=cluster_poc
```
