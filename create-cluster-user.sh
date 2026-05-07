#!/usr/bin/env bash

set -Eeuo pipefail

MYSQL_NAME="${MYSQL_NAME:-mysql1}"
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-ClusterRoot123!}"
DB_USER="${1:-}"
DB_PASSWORD="${2:-}"
TARGET_DATABASE="${3:-*}"
TARGET_HOST="${TARGET_HOST:-%}"
GRANT_PRIVILEGES="${GRANT_PRIVILEGES:-ALL PRIVILEGES}"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

usage() {
  cat <<'EOF'
Uso:
  bash ./create-cluster-user.sh <user> <password> [database]

Parametros:
  user       Nome do usuario a ser criado
  password   Senha do usuario
  database   Banco que recebera grants. Default: * (todos)

Variaveis opcionais:
  MYSQL_NAME             Container MySQL do cluster. Default: mysql1
  MYSQL_ROOT_PASSWORD    Senha do root. Default: ClusterRoot123!
  TARGET_HOST            Host do usuario no MySQL. Default: %
  GRANT_PRIVILEGES       Privilegios concedidos. Default: ALL PRIVILEGES

Exemplos:
  bash ./create-cluster-user.sh app_user 'Senha123!' app_db
  TARGET_HOST=127.0.0.1 bash ./create-cluster-user.sh local_user 'Senha123!' app_db
  GRANT_PRIVILEGES='SELECT,INSERT,UPDATE,DELETE' bash ./create-cluster-user.sh api_user 'Senha123!' app_db
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

grant_scope() {
  if [[ "$TARGET_DATABASE" == "*" ]]; then
    printf '*.*'
    return 0
  fi

  printf '`%s`.*' "$TARGET_DATABASE"
}

main() {
  command -v docker >/dev/null 2>&1 || {
    printf 'Comando obrigatorio nao encontrado: docker\n' >&2
    exit 1
  }

  if [[ -z "$DB_USER" || -z "$DB_PASSWORD" || "$DB_USER" == "-h" || "$DB_USER" == "--help" ]]; then
    usage
    exit 0
  fi

  require_ready_container

  local scope
  scope="$(grant_scope)"

  log "Criando usuario $DB_USER@$TARGET_HOST no container $MYSQL_NAME."
  docker exec "$MYSQL_NAME" mysql -uroot "-p$MYSQL_ROOT_PASSWORD" -e "
    CREATE USER IF NOT EXISTS '${DB_USER}'@'${TARGET_HOST}' IDENTIFIED BY '${DB_PASSWORD}';
    GRANT ${GRANT_PRIVILEGES} ON ${scope} TO '${DB_USER}'@'${TARGET_HOST}';
    FLUSH PRIVILEGES;
  " >/dev/null

  log "Usuario $DB_USER@$TARGET_HOST pronto com grants em ${scope}."
}

main "$@"
