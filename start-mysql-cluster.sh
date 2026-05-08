#!/usr/bin/env bash

set -Eeuo pipefail

NETWORK_NAME="${NETWORK_NAME:-cluster}"
SUBNET_CIDR="${SUBNET_CIDR:-10.66.0.0/24}"
IMAGE_NAME="${IMAGE_NAME:-mysql/mysql-cluster}"
RUNTIME_DIR="${RUNTIME_DIR:-.cluster-runtime}"

MANAGER_NAME="${MANAGER_NAME:-management1}"
MANAGER_IP="${MANAGER_IP:-10.66.0.2}"

NDB1_NAME="${NDB1_NAME:-ndb1}"
NDB1_IP="${NDB1_IP:-10.66.0.3}"

NDB2_NAME="${NDB2_NAME:-ndb2}"
NDB2_IP="${NDB2_IP:-10.66.0.4}"

MYSQL_NAME="${MYSQL_NAME:-mysql1}"
MYSQL_IP="${MYSQL_IP:-10.66.0.10}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-ClusterRoot123!}"
APP_DB_USER="${APP_DB_USER:-cluster_app}"
APP_DB_PASSWORD="${APP_DB_PASSWORD:-ClusterApp123!}"
APP_DB_AUTH_PLUGIN="${APP_DB_AUTH_PLUGIN:-mysql_native_password}"
PUBLISH_MYSQL_PORT="${PUBLISH_MYSQL_PORT:-true}"
STOP_FIVEM_MYSQL="${STOP_FIVEM_MYSQL:-true}"

CLUSTER_CONTAINERS=(
  "$MANAGER_NAME"
  "$NDB1_NAME"
  "$NDB2_NAME"
  "$MYSQL_NAME"
)

CLUSTER_CONFIG_FILE=""

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

container_exists() {
  docker container inspect "$1" >/dev/null 2>&1
}

container_running() {
  [[ "$(docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null || true)" == "true" ]]
}

container_health() {
  docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$1" 2>/dev/null || true
}

container_status() {
  docker inspect -f '{{.State.Status}}' "$1" 2>/dev/null || true
}

print_logs() {
  local name="$1"
  if container_exists "$name"; then
    log "Latest log lines from $name:"
    docker logs --tail 80 "$name" || true
  fi
}

on_error() {
  local exit_code="$?"
  log "Failed to start cluster (exit code $exit_code)."
  for name in "${CLUSTER_CONTAINERS[@]}"; do
    print_logs "$name"
  done
  exit "$exit_code"
}

trap on_error ERR

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'Required command not found: %s\n' "$1" >&2
    exit 1
  }
}

runtime_dir_abs() {
  mkdir -p "$RUNTIME_DIR"
  cd "$RUNTIME_DIR" >/dev/null 2>&1
  pwd
}

network_subnet() {
  docker network inspect "$NETWORK_NAME" -f '{{(index .IPAM.Config 0).Subnet}}' 2>/dev/null || true
}

generate_cluster_config() {
  local runtime_dir
  runtime_dir="$(runtime_dir_abs)"
  CLUSTER_CONFIG_FILE="$runtime_dir/mysql-cluster.cnf"

  cat >"$CLUSTER_CONFIG_FILE" <<EOF
[NDBD DEFAULT]
NoOfReplicas=2
DataMemory=80M
IndexMemory=18M

[TCP DEFAULT]

[NDB_MGMD]
NodeId=1
HostName=$MANAGER_IP

[NDBD]
NodeId=2
HostName=$NDB1_IP

[NDBD]
NodeId=3
HostName=$NDB2_IP

[MYSQLD]
NodeId=4
HostName=$MYSQL_IP
EOF

  log "Generated cluster config at $CLUSTER_CONFIG_FILE."
}

wait_for_running() {
  local name="$1"
  local timeout="${2:-90}"
  local waited=0

  while (( waited < timeout )); do
    if container_running "$name"; then
      log "$name is running."
      return 0
    fi
    sleep 2
    waited=$((waited + 2))
  done

  log "Timed out waiting for $name to start running."
  return 1
}

wait_for_healthy() {
  local name="$1"
  local timeout="${2:-180}"
  local waited=0
  local health status

  while (( waited < timeout )); do
    status="$(container_status "$name")"
    health="$(container_health "$name")"

    if [[ "$status" != "running" && "$status" != "created" ]]; then
      log "$name stopped with status '$status'."
      return 1
    fi

    if [[ "$health" == "healthy" ]]; then
      log "$name is healthy."
      return 0
    fi

    if [[ "$health" == "unhealthy" ]]; then
      log "$name became unhealthy."
      return 1
    fi

    sleep 3
    waited=$((waited + 3))
  done

  log "Timed out waiting for healthcheck on $name."
  return 1
}

ensure_network() {
  if docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
    local existing_subnet
    existing_subnet="$(network_subnet)"

    if [[ "$existing_subnet" == "$SUBNET_CIDR" ]]; then
      log "Network $NETWORK_NAME already exists."
      return 0
    fi

    log "Network $NETWORK_NAME exists with subnet $existing_subnet and will be recreated for $SUBNET_CIDR."
    docker network rm "$NETWORK_NAME" >/dev/null
    log "Creating network $NETWORK_NAME ($SUBNET_CIDR)."
    docker network create "$NETWORK_NAME" --subnet "$SUBNET_CIDR" >/dev/null
    return 0
  fi

  log "Creating network $NETWORK_NAME ($SUBNET_CIDR)."
  docker network create "$NETWORK_NAME" --subnet "$SUBNET_CIDR" >/dev/null
}

cleanup_cluster() {
  log "Removing old cluster containers if they exist."
  for name in "${CLUSTER_CONTAINERS[@]}"; do
    if container_exists "$name"; then
      docker rm -f "$name" >/dev/null
    fi
  done
}

stop_fivem_mysql_if_needed() {
  if [[ "$PUBLISH_MYSQL_PORT" != "true" || "$STOP_FIVEM_MYSQL" != "true" ]]; then
    return 0
  fi

  if container_exists "fivem_mysql" && container_running "fivem_mysql"; then
    log "Stopping fivem_mysql to free port $MYSQL_PORT."
    docker stop fivem_mysql >/dev/null
  fi
}

run_manager() {
  log "Starting management node."
  docker create \
    --net "$NETWORK_NAME" \
    --name "$MANAGER_NAME" \
    --ip "$MANAGER_IP" \
    --health-cmd="sh -c 'ndb_mgm -c $MANAGER_IP -e show >/dev/null 2>&1'" \
    --health-interval=10s \
    --health-timeout=10s \
    --health-retries=12 \
    --health-start-period=10s \
    "$IMAGE_NAME" \
    ndb_mgmd -f /etc/mysql-cluster.cnf >/dev/null

  docker cp "$CLUSTER_CONFIG_FILE" "$MANAGER_NAME:/etc/mysql-cluster.cnf" >/dev/null
  docker start "$MANAGER_NAME" >/dev/null
}

run_data_node() {
  local name="$1"
  local ip="$2"

  log "Starting data node $name."
  docker run -d \
    --net "$NETWORK_NAME" \
    --name "$name" \
    --ip "$ip" \
    --health-cmd="sh -c 'ndb_mgm -c $MANAGER_NAME -e show 2>/dev/null | grep -q \"@$ip\"'" \
    --health-interval=10s \
    --health-timeout=5s \
    --health-retries=12 \
    --health-start-period=20s \
    "$IMAGE_NAME" \
    ndbd "--ndb-connectstring=$MANAGER_IP" >/dev/null
}

run_mysql_server() {
  local port_args=()
  if [[ "$PUBLISH_MYSQL_PORT" == "true" ]]; then
    port_args=(-p "$MYSQL_PORT:3306")
  fi

  log "Starting MySQL server."
  docker run -d \
    --net "$NETWORK_NAME" \
    --name "$MYSQL_NAME" \
    --ip "$MYSQL_IP" \
    "${port_args[@]}" \
    -e "MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD" \
    --health-cmd="mysqladmin ping -h 127.0.0.1 -uroot -p$MYSQL_ROOT_PASSWORD --silent" \
    --health-interval=10s \
    --health-timeout=5s \
    --health-retries=20 \
    --health-start-period=30s \
    "$IMAGE_NAME" \
    mysqld "--ndb-connectstring=$MANAGER_IP" >/dev/null
}

configure_app_user() {
  log "Configuring remote application user."
  docker exec "$MYSQL_NAME" mysql -uroot "-p$MYSQL_ROOT_PASSWORD" -e "
    CREATE USER IF NOT EXISTS '${APP_DB_USER}'@'%' IDENTIFIED WITH ${APP_DB_AUTH_PLUGIN} BY '${APP_DB_PASSWORD}';
    ALTER USER '${APP_DB_USER}'@'%' IDENTIFIED WITH ${APP_DB_AUTH_PLUGIN} BY '${APP_DB_PASSWORD}';
    GRANT ALL PRIVILEGES ON *.* TO '${APP_DB_USER}'@'%' WITH GRANT OPTION;
    FLUSH PRIVILEGES;
  " >/dev/null
}

show_cluster_status() {
  log "Final cluster status:"
  docker run --rm --net "$NETWORK_NAME" "$IMAGE_NAME" \
    ndb_mgm -c "$MANAGER_IP" -e show
}

show_summary() {
  log "Container summary:"
  docker ps --filter "name=^/${MANAGER_NAME}$" \
            --filter "name=^/${NDB1_NAME}$" \
            --filter "name=^/${NDB2_NAME}$" \
            --filter "name=^/${MYSQL_NAME}$" \
            --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
}

main() {
  require_command docker

  log "Validating image $IMAGE_NAME."
  docker image inspect "$IMAGE_NAME" >/dev/null 2>&1 || docker pull "$IMAGE_NAME" >/dev/null

  stop_fivem_mysql_if_needed
  cleanup_cluster
  generate_cluster_config
  ensure_network

  run_manager
  wait_for_running "$MANAGER_NAME"
  wait_for_healthy "$MANAGER_NAME"

  run_data_node "$NDB1_NAME" "$NDB1_IP"
  wait_for_running "$NDB1_NAME"
  wait_for_healthy "$NDB1_NAME"

  run_data_node "$NDB2_NAME" "$NDB2_IP"
  wait_for_running "$NDB2_NAME"
  wait_for_healthy "$NDB2_NAME"

  run_mysql_server
  wait_for_running "$MYSQL_NAME"
  wait_for_healthy "$MYSQL_NAME" 240
  configure_app_user

  show_summary
  show_cluster_status

  log "Cluster is ready."
  log "Current root password: $MYSQL_ROOT_PASSWORD"
  log "Application user: $APP_DB_USER"
  log "Application user password: $APP_DB_PASSWORD"
  log "Example to create a database: bash ./create-cluster-database.sh app_db"
  log "Example to create a user: bash ./create-cluster-user.sh app_user 'Password123!' app_db"
}

main "$@"
