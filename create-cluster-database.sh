#!/usr/bin/env bash

set -Eeuo pipefail

MYSQL_NAME="${MYSQL_NAME:-mysql1}"
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-ClusterRoot123!}"
DB_NAME="${1:-}"
DB_CHARSET="${DB_CHARSET:-utf8mb4}"
DB_COLLATION="${DB_COLLATION:-utf8mb4_unicode_ci}"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

usage() {
  cat <<'EOF'
Uso:
  bash ./create-cluster-database.sh <database_name>

Variaveis opcionais:
  MYSQL_NAME             Container MySQL do cluster. Default: mysql1
  MYSQL_ROOT_PASSWORD    Senha do root. Default: ClusterRoot123!
  DB_CHARSET             Charset do banco. Default: utf8mb4
  DB_COLLATION           Collation do banco. Default: utf8mb4_unicode_ci

Exemplos:
  bash ./create-cluster-database.sh app_db
  DB_CHARSET=utf8mb4 DB_COLLATION=utf8mb4_general_ci bash ./create-cluster-database.sh logs_db
EOF
}

require_ready_container() {
  docker container inspect "$MYSQL_NAME" >/dev/null 2>&1 || {
    printf 'Container %s nao existe.\n' "$MYSQL_NAME" >&2
    exit 1
  }

  [[ "$(docker inspect -f '{{.State.Running}}' "$MYSQL_NAME")" == "true" ]] || {
    printf 'Container %s nao esta em execucao.\n' "$MYSQL_NAME" >&2
    exit 1
  }
}

main() {
  command -v docker >/dev/null 2>&1 || {
    printf 'Comando obrigatorio nao encontrado: docker\n' >&2
    exit 1
  }

  if [[ -z "$DB_NAME" || "$DB_NAME" == "-h" || "$DB_NAME" == "--help" ]]; then
    usage
    exit 0
  fi

  require_ready_container

  log "Criando database $DB_NAME no container $MYSQL_NAME."
  docker exec "$MYSQL_NAME" mysql -uroot "-p$MYSQL_ROOT_PASSWORD" -e "
    CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`
    CHARACTER SET $DB_CHARSET
    COLLATE $DB_COLLATION;
  " >/dev/null

  log "Database $DB_NAME pronta."
}

main "$@"
