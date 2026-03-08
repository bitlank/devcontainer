#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="${DIR}/.dev/devcontainer.sh"
UPDATE=false

if [ "${1:-}" = "--update" ]; then
  UPDATE=true
  shift
fi

if [ "$UPDATE" = true ] || [ ! -f "$SCRIPT" ]; then
  mkdir -p "${DIR}/.dev"
  curl -fsSL "https://github.com/bitlank/devcontainer/releases/latest/download/devcontainer.sh" \
    -o "$SCRIPT"
  chmod +x "$SCRIPT"
fi

exec "$SCRIPT" "$@"
