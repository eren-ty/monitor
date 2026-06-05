#!/usr/bin/env sh
set -eu

PROJECT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$PROJECT_DIR"

if [ ! -d .git ]; then
  echo "This directory is not a Git repository: $PROJECT_DIR" >&2
  exit 1
fi

CURRENT_REV="$(git rev-parse HEAD)"
git fetch --prune
git pull --ff-only
NEW_REV="$(git rev-parse HEAD)"

if [ "$CURRENT_REV" = "$NEW_REV" ]; then
  echo "No Git changes. Skip redeploy."
  exit 0
fi

docker compose pull
docker compose up -d --build --remove-orphans
docker compose ps

