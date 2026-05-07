#!/usr/bin/env bash

set -Eeuo pipefail

MYSQL_NAME="${MYSQL_NAME:-mysql1}"
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-ClusterRoot123!}"
DB_USER="${1:-}"
DB_PASSWORD="${2:-}"
TARGET_DATABASE="${3:-*}"
TARGET_HOST="${TARGET_HOST:-%}"
GRANT_PRIVILEGES="${GRANT_PRIVILEGES:-ALL PRIVILEGES}"
AUTH_PLUGIN="${AUTH_PLUGIN:-mysql_native_password}"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

usage() {
  cat <<'EOF'
Usage:
  bash ./create-cluster-user.sh <user> <password> [database]

Parameters:
  user       User name to create
  password   User password
  database   Database that receives grants. Default: * (all)

Optional variables:
  MYSQL_NAME             Cluster MySQL container. Default: mysql1
  MYSQL_ROOT_PASSWORD    Root password. Default: ClusterRoot123!
  TARGET_HOST            MySQL host for the user. Default: %
  GRANT_PRIVILEGES       Granted privileges. Default: ALL PRIVILEGES
  AUTH_PLUGIN            Authentication plugin. Default: mysql_native_password

Examples:
  bash ./create-cluster-user.sh app_user 'Password123!' app_db
  TARGET_HOST=127.0.0.1 bash ./create-cluster-user.sh local_user 'Password123!' app_db
  GRANT_PRIVILEGES='SELECT,INSERT,UPDATE,DELETE' bash ./create-cluster-user.sh api_user 'Password123!' app_db
EOF
}

require_ready_container() {
  docker container inspect "$MYSQL_NAME" >/dev/null 2>&1 || {
    printf 'Container %s does not exist.\n' "$MYSQL_NAME" >&2
    exit 1
  }

  [[ "$(docker inspect -f '{{.State.Running}}' "$MYSQL_NAME")" == "true" ]] || {
    printf 'Container %s is not running.\n' "$MYSQL_NAME" >&2
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
    printf 'Required command not found: docker\n' >&2
    exit 1
  }

  if [[ -z "$DB_USER" || -z "$DB_PASSWORD" || "$DB_USER" == "-h" || "$DB_USER" == "--help" ]]; then
    usage
    exit 0
  fi

  require_ready_container

  local scope
  scope="$(grant_scope)"

  log "Creating user $DB_USER@$TARGET_HOST in container $MYSQL_NAME."
  docker exec "$MYSQL_NAME" mysql -uroot "-p$MYSQL_ROOT_PASSWORD" -e "
    CREATE USER IF NOT EXISTS '${DB_USER}'@'${TARGET_HOST}' IDENTIFIED WITH ${AUTH_PLUGIN} BY '${DB_PASSWORD}';
    ALTER USER '${DB_USER}'@'${TARGET_HOST}' IDENTIFIED WITH ${AUTH_PLUGIN} BY '${DB_PASSWORD}';
    GRANT ${GRANT_PRIVILEGES} ON ${scope} TO '${DB_USER}'@'${TARGET_HOST}';
    FLUSH PRIVILEGES;
  " >/dev/null

  log "User $DB_USER@$TARGET_HOST is ready with grants on ${scope}."
}

main "$@"
