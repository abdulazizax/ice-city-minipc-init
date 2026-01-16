#!/usr/bin/env bash
# Autostart script: pulls latest images and (re)starts the stack
# Safe for repeated runs.

set -euo pipefail
cd "$(dirname "$0")"

# Export env if present
if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi

# Ensure Docker is up
if ! docker info >/dev/null 2>&1; then
  echo "Docker daemon not available. Exiting." >&2
  exit 1
fi

# Pull latest images for referenced services
# Compose v2 supports 'compose pull'
if docker compose version >/dev/null 2>&1; then
  docker compose pull --quiet || true
  docker compose up -d --remove-orphans
else
  # Fallback to legacy docker-compose if available
  if command -v docker-compose >/dev/null 2>&1; then
    docker-compose pull || true
    docker-compose up -d --remove-orphans
  else
    echo "docker compose or docker-compose not found" >&2
    exit 1
  fi
fi

# Optional: prune dangling images to save space
if command -v docker >/dev/null 2>&1; then
  docker image prune -f >/dev/null 2>&1 || true
fi

echo "Autostart complete."
