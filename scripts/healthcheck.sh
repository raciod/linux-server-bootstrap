#!/usr/bin/env bash
# a script that checks if a docker container is running, restarts it if not
set -euo pipefail

# Variables
dockerContainer="nginx"

# functions
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# get the container ID for the 'web' service (empty string if not running)
container_id=$(docker compose ps -q web)

if [ -z "$container_id" ]; then
  log "$dockerContainer is not running (no container found), starting it..."
  docker compose up -d
elif [ "$(docker inspect -f '{{.State.Running}}' "$container_id")" = "true" ]; then
  log "$dockerContainer is running"
else
  log "$dockerContainer is not running, restarting..."
  docker compose up -d
fi
