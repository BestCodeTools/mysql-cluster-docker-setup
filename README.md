# MySQL Cluster com Docker

Este projeto empacota um setup simples de **MySQL Cluster** com:

- `1` management node
- `2` data nodes
- `1` MySQL server node
- scripts Bash para criar databases e usuarios
- `1` PoC Node.js para validar conexao com `sequelize` e migration com `knex`

O objetivo aqui e subir o cluster de forma previsivel com shell script Bash, validar que todos os containers ficam `healthy`, e testar uma aplicacao Node.js contra esse ambiente.

## Estrutura

- [start-mysql-cluster.sh](X:/DEV/docker/mysql-cluster/start-mysql-cluster.sh): sobe o cluster, espera readiness e cria usuario remoto de aplicacao
- [stop-mysql-cluster.sh](X:/DEV/docker/mysql-cluster/stop-mysql-cluster.sh): remove containers do cluster e, por padrao, remove a rede
- [create-cluster-database.sh](X:/DEV/docker/mysql-cluster/create-cluster-database.sh): cria um database dentro do node SQL do cluster
- [create-cluster-user.sh](X:/DEV/docker/mysql-cluster/create-cluster-user.sh): cria usuario e grants dentro do node SQL do cluster
- [.github/workflows/mysql-cluster-validation.yml](X:/DEV/docker/mysql-cluster/.github/workflows/mysql-cluster-validation.yml): workflow de CI para validar cluster, provisioning e acesso da aplicacao
- [GUIDELINES.md](X:/DEV/docker/mysql-cluster/GUIDELINES.md): referencia original baseada no guia da imagem `mysql/mysql-cluster`
- [poc-node-cluster](X:/DEV/docker/mysql-cluster/poc-node-cluster/README.md): PoC Node.js para validacao

## Requisitos

- Docker instalado e funcional
- Bash disponivel
  - Exemplo: WSL Ubuntu, Git Bash ou ambiente Linux
- Porta `3306` livre no host se voce quiser publicar o MySQL externamente

## Como subir o cluster

Na raiz do projeto:

```bash
bash ./start-mysql-cluster.sh
```

O script faz o seguinte:

1. Garante que a imagem `mysql/mysql-cluster` exista localmente
2. Para o container `fivem_mysql` se ele estiver rodando e se a porta `3306` precisar ser liberada
3. Remove containers antigos do cluster, se existirem
4. Cria a rede Docker `cluster`
5. Sobe `management1`
6. Sobe `ndb1`
7. Sobe `ndb2`
8. Sobe `mysql1`
9. Aguarda todos ficarem `healthy`
10. Cria um usuario remoto para a aplicacao
11. Exibe exemplos para usar os scripts de criacao de database e usuario

## Recursos criados

Por padrao, o cluster sobe com:

- Rede Docker: `cluster`
- Management node: `management1` em `192.168.0.2`
- Data node 1: `ndb1` em `192.168.0.3`
- Data node 2: `ndb2` em `192.168.0.4`
- MySQL server: `mysql1` em `192.168.0.10`
- Porta publicada no host: `3306`

## Credenciais padrao

O script de subida define por padrao:

- `root`: `ClusterRoot123!`
- usuario de aplicacao: `cluster_app`
- senha do usuario de aplicacao: `ClusterApp123!`

Observacao importante:

O `root` do container funciona bem para administracao dentro do proprio container, mas para conexoes externas do host a melhor opcao aqui e usar o usuario `cluster_app`, que ja e provisionado pelo script.

## Variaveis de ambiente uteis

Voce pode sobrescrever os defaults ao chamar o script.

### Subida

```bash
MYSQL_ROOT_PASSWORD='OutraSenhaRoot123!'
APP_DB_USER='app_user'
APP_DB_PASSWORD='AppPass123!'
bash ./start-mysql-cluster.sh
```

Outras variaveis suportadas no script de subida:

- `NETWORK_NAME`
- `SUBNET_CIDR`
- `IMAGE_NAME`
- `MANAGER_NAME`
- `MANAGER_IP`
- `NDB1_NAME`
- `NDB1_IP`
- `NDB2_NAME`
- `NDB2_IP`
- `MYSQL_NAME`
- `MYSQL_IP`
- `MYSQL_PORT`
- `PUBLISH_MYSQL_PORT`
- `STOP_FIVEM_MYSQL`

Exemplo sem publicar a porta `3306`:

```bash
PUBLISH_MYSQL_PORT=false bash ./start-mysql-cluster.sh
```

## Como criar databases e usuarios no cluster

Este projeto inclui dois scripts auxiliares para administracao basica:

- [create-cluster-database.sh](X:/DEV/docker/mysql-cluster/create-cluster-database.sh)
- [create-cluster-user.sh](X:/DEV/docker/mysql-cluster/create-cluster-user.sh)

### Observacao importante sobre onde os comandos rodam

Neste setup, os comandos SQL sao executados diretamente dentro do container `mysql1`, que e o **MySQL server node** do cluster.

Isso e o comportamento correto aqui porque:

- `management1` e usado para gerenciamento do cluster, nao para executar SQL da aplicacao
- `ndb1` e `ndb2` sao data nodes, nao endpoints SQL
- `mysql1` e o node que aceita conexoes MySQL e propaga o uso do storage engine `NDBCLUSTER` sobre o cluster

Ou seja: para criar database, usuario, grants e tabelas, o ponto certo neste projeto e o `mysql1`.

### Criar um database

Uso basico:

```bash
bash ./create-cluster-database.sh app_db
```

Exemplo com charset/collation customizados:

```bash
DB_CHARSET=utf8mb4 DB_COLLATION=utf8mb4_general_ci bash ./create-cluster-database.sh logs_db
```

Variaveis suportadas:

- `MYSQL_NAME`
- `MYSQL_ROOT_PASSWORD`
- `DB_CHARSET`
- `DB_COLLATION`

### Criar um usuario com grant

Uso basico:

```bash
bash ./create-cluster-user.sh app_user 'Senha123!' app_db
```

Esse comando:

- cria `app_user`
- define a senha informada
- concede `ALL PRIVILEGES` em `app_db.*`

Exemplo restringindo o host:

```bash
TARGET_HOST=127.0.0.1 bash ./create-cluster-user.sh local_user 'Senha123!' app_db
```

Exemplo com privilegios especificos:

```bash
GRANT_PRIVILEGES='SELECT,INSERT,UPDATE,DELETE' bash ./create-cluster-user.sh api_user 'Senha123!' app_db
```

Variaveis suportadas:

- `MYSQL_NAME`
- `MYSQL_ROOT_PASSWORD`
- `TARGET_HOST`
- `GRANT_PRIVILEGES`

### Fluxo recomendado

Para provisionar um banco de aplicacao do zero:

```bash
bash ./create-cluster-database.sh minha_app
bash ./create-cluster-user.sh minha_app_user 'MinhaSenha123!' minha_app
```

Depois disso, a aplicacao pode apontar para:

- host: `127.0.0.1`
- port: `3306`
- database: `minha_app`
- user: `minha_app_user`
- password: a senha configurada

## Como parar e remover o cluster

Na raiz do projeto:

```bash
bash ./stop-mysql-cluster.sh
```

O script remove:

1. `mysql1`
2. `ndb2`
3. `ndb1`
4. `management1`
5. rede `cluster`

Se quiser preservar a rede:

```bash
REMOVE_NETWORK=false bash ./stop-mysql-cluster.sh
```

## Como validar com a PoC Node.js

A PoC fica em [poc-node-cluster](X:/DEV/docker/mysql-cluster/poc-node-cluster/README.md).

Ela valida tres pontos:

1. Conexao de uma aplicacao Node.js ao cluster usando `sequelize`
2. Criacao de tabela com `knex migration`
3. Confirmacao de que a tabela foi criada com `ENGINE=NDBCLUSTER`

### Instalar dependencias

No Windows, seguindo a preferencia do projeto:

```bash
cd poc-node-cluster
npm.cmd install
```

No Linux ou WSL:

```bash
cd poc-node-cluster
npm install
```

### Executar a validacao completa

No Windows:

```bash
npm.cmd run test:all
```

No Linux ou WSL:

```bash
npm run test:all
```

### O que a PoC faz

- prepara o acesso ao banco informado
- valida que o engine `NDBCLUSTER` esta disponivel
- executa a migration que cria a tabela `cluster_messages`
- valida a conexao com `sequelize`
- executa insert, select e delete com raw query
- executa insert, select e delete com `sequelize`
- confirma no `information_schema` que a tabela usa `NDBCLUSTER`

## Validacao automatica com GitHub Actions

O projeto inclui a workflow [mysql-cluster-validation.yml](X:/DEV/docker/mysql-cluster/.github/workflows/mysql-cluster-validation.yml), que executa este fluxo:

1. instala as dependencias da PoC Node.js
2. sobe o cluster com `start-mysql-cluster.sh`
3. cria um database dedicado para validacao
4. cria um usuario dedicado para validacao
5. executa a PoC Node.js com esse usuario
6. roda migration via `knex`
7. valida CRUD com raw query
8. valida CRUD com `sequelize`
9. derruba o cluster ao final, mesmo se houver falha

Ela e disparada em:

- `push` para `main`
- `push` para `master`
- `pull_request`
- execucao manual com `workflow_dispatch`

## Configuracao da PoC

Defaults da PoC:

- `DB_HOST=127.0.0.1`
- `DB_PORT=3306`
- `DB_USER=cluster_app`
- `DB_PASSWORD=ClusterApp123!`
- `DB_NAME=cluster_poc`

Exemplo sobrescrevendo:

```bash
DB_HOST=127.0.0.1 \
DB_PORT=3306 \
DB_USER=cluster_app \
DB_PASSWORD='ClusterApp123!' \
DB_NAME=cluster_poc \
npm run test:all
```

## Como verificar manualmente o status do cluster

### Ver containers

```bash
docker ps
```

Voce deve ver `management1`, `ndb1`, `ndb2` e `mysql1` com status `healthy`.

### Consultar o management client

```bash
docker run --rm --net cluster mysql/mysql-cluster ndb_mgm -c 192.168.0.2 -e show
```

Voce deve ver:

- `2` nodes `ndbd(NDB)`
- `1` node `ndb_mgmd(MGM)`
- `1` node `mysqld(API)`

## Problemas comuns

### So o `mysql1` fica healthy

Esse foi justamente o problema resolvido por este projeto. O ponto principal e:

- respeitar a ordem estrita de inicializacao
- esperar cada container ficar pronto antes de subir o proximo
- usar verificacoes de health separadas para manager, data nodes e MySQL server

### `Host '_gateway' is not allowed to connect`

Isso acontece ao tentar conectar do host usando `root`. O script ja resolve isso criando `cluster_app@'%'`.

### Porta `3306` ocupada

Se existir outro MySQL rodando, a publicacao da porta pode falhar ou causar conflito. O script tenta parar o container `fivem_mysql` por padrao para liberar essa porta.

Se preferir nao publicar `3306`, use:

```bash
PUBLISH_MYSQL_PORT=false bash ./start-mysql-cluster.sh
```

### Quero limpar tudo e subir de novo

```bash
bash ./stop-mysql-cluster.sh
bash ./start-mysql-cluster.sh
```

### Quero criar novos bancos e usuarios depois que o cluster ja esta no ar

```bash
bash ./create-cluster-database.sh outro_db
bash ./create-cluster-user.sh outro_user 'OutraSenha123!' outro_db
```

## Observacoes

- Este setup foi pensado para ambiente local e PoC
- Os scripts sao idempotentes o suficiente para facilitar reexecucao
- A migration da PoC cria explicitamente a tabela com `ENGINE=NDBCLUSTER`
- O cluster foi validado localmente com os 4 containers em estado `healthy`
- Os scripts de criacao de database e usuario foram validados localmente contra o container `mysql1`

## Referencias

- [GUIDELINES.md](X:/DEV/docker/mysql-cluster/GUIDELINES.md)
- [MySQL Cluster image no Docker Hub](https://hub.docker.com/r/mysql/mysql-cluster)
