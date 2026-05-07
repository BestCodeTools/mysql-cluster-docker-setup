#!/usr/bin/env bash

set -Eeuo pipefail

NETWORK_NAME="${NETWORK_NAME:-cluster}"
MANAGER_NAME="${MANAGER_NAME:-management1}"
NDB1_NAME="${NDB1_NAME:-ndb1}"
NDB2_NAME="${NDB2_NAME:-ndb2}"
MYSQL_NAME="${MYSQL_NAME:-mysql1}"
REMOVE_NETWORK="${REMOVE_NETWORK:-true}"

CLUSTER_CONTAINERS=(
  "$MYSQL_NAME"
  "$NDB2_NAME"
  "$NDB1_NAME"
  "$MANAGER_NAME"
)

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

container_exists() {
  docker container inspect "$1" >/dev/null 2>&1
}

remove_container_if_exists() {
  local name="$1"

  if container_exists "$name"; then
    log "Removing container $name."
    docker rm -f "$name" >/dev/null
    return 0
  fi

  log "Container $name does not exist, nothing to remove."
}

remove_network_if_requested() {
  if [[ "$REMOVE_NETWORK" != "true" ]]; then
    log "Network $NETWORK_NAME preserved because REMOVE_NETWORK=$REMOVE_NETWORK."
    return 0
  fi

  if docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
    log "Removing network $NETWORK_NAME."
    docker network rm "$NETWORK_NAME" >/dev/null
    return 0
  fi

  log "Network $NETWORK_NAME does not exist, nothing to remove."
}

show_remaining_cluster_state() {
  log "Remaining state for cluster-named resources:"
  docker ps -a \
    --filter "name=^/${MANAGER_NAME}$" \
    --filter "name=^/${NDB1_NAME}$" \
    --filter "name=^/${NDB2_NAME}$" \
    --filter "name=^/${MYSQL_NAME}$" \
    --format 'table {{.Names}}\t{{.Status}}'
}

main() {
  command -v docker >/dev/null 2>&1 || {
    printf 'Required command not found: docker\n' >&2
    exit 1
  }

  log "Stopping and removing cluster containers."
  for name in "${CLUSTER_CONTAINERS[@]}"; do
    remove_container_if_exists "$name"
  done

  remove_network_if_requested
  show_remaining_cluster_state
  log "Cluster shutdown complete."
}

main "$@"
