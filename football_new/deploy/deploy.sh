#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 user@server [remote_dir]"
  exit 1
fi

REMOTE_HOST="$1"
REMOTE_DIR="${2:-/opt/football-app}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${PROJECT_ROOT}/deploy/.env.prod"
EXCLUDE_FILE="${PROJECT_ROOT}/deploy/rsync-exclude.txt"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}. Copy deploy/.env.prod.example and fill real values."
  exit 1
fi

echo "Syncing project to ${REMOTE_HOST}:${REMOTE_DIR}"
rsync -az --delete \
  --exclude-from="${EXCLUDE_FILE}" \
  "${PROJECT_ROOT}/" "${REMOTE_HOST}:${REMOTE_DIR}/"

echo "Uploading production env file"
scp "${ENV_FILE}" "${REMOTE_HOST}:${REMOTE_DIR}/deploy/.env.prod"

echo "Starting containers on server"
ssh "${REMOTE_HOST}" "cd '${REMOTE_DIR}' && docker compose --env-file deploy/.env.prod -f docker-compose.prod.yml up -d --build"

echo "Deployment finished"
