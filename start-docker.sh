#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if ! command -v docker-compose >/dev/null 2>&1; then
  echo "docker-compose is not installed. Please install Docker Desktop or docker-compose."
  exit 1
fi

cd "$SCRIPT_DIR"
docker-compose up --build -d
