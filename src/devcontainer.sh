#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
BASE_IMAGE="ghcr.io/bitlank/devcontainer:latest"
SCHEMA_VERSION=1

NETWORK="devcontainer-net"
DIND="devcontainer-dind"
BUILD=false
FORCE_BASE=false
WORKSPACE=""
DOCKER_ARGS=()
PARSE_REMAINING=()

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] [COMMAND...]

Launch a dev container for a project directory.

Options:
  -w, --workspace DIR  Project directory to mount (default: current directory)
  --build              Force rebuild of the container image(s)
  --mount MOUNT        Pass a --mount argument to docker run
  -v, --volume VOL     Pass a --volume argument to docker run
  -p, --publish PORT   Pass a --publish argument to docker run
  -e, --env KEY=VAL    Pass an environment variable to the container
  --env-file FILE      Pass an env file to the container
  --base               Force use of the base devcontainer image (ignore project Dockerfile)
  -h, --help           Show this help message

Arguments:
  COMMAND...           Command to run inside the container (default: interactive shell)

Project customization (under .dev/ in the workspace):
  .dev/Dockerfile      Optional Dockerfile extending the base image
  .dev/volumes         Optional list of -v values, one per line (# for comments)
  .dev/ports           Optional list of -p values, one per line (# for comments)
  .dev/env             Optional env file passed to docker
  .dev/state/          Per-user state (claude config, bash history) — gitignore
  .dev/version         Layout schema version (managed automatically)
EOF
}

parse_flags() {
  while [[ "${1:-}" == --* || "${1:-}" == -?* ]]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      -w|--workspace)
        if [ -n "$WORKSPACE" ]; then
          echo "Error: --workspace specified more than once" >&2; exit 1
        fi
        WORKSPACE="$2"; shift 2 ;;
      --base) FORCE_BASE=true; shift ;;
      --build) BUILD=true; shift ;;
      --mount) DOCKER_ARGS+=(--mount "$2"); shift 2 ;;
      -v|--volume) DOCKER_ARGS+=(--volume "$2"); shift 2 ;;
      -p|--publish) DOCKER_ARGS+=(--publish "$2"); shift 2 ;;
      -e|--env) DOCKER_ARGS+=(--env "$2"); shift 2 ;;
      --env-file) DOCKER_ARGS+=(--env-file "$2"); shift 2 ;;
      *) echo "Unknown option: $1" >&2; echo >&2; usage >&2; exit 1 ;;
    esac
  done
  PARSE_REMAINING=("$@")
}

load_lines() {
  local file="$1" flag="$2"
  [ -f "$file" ] || return 0
  local line
  while IFS= read -r line; do
    case "$line" in ''|'#'*) continue ;; esac
    DOCKER_ARGS+=("$flag" "$line")
  done < "$file"
}

migrate_v0_to_v1() {
  local dev_dir="$1"
  local f
  if [ ! -d "$dev_dir/state" ]; then
    local has_state=0
    for f in .claude .claude.json .bash_history; do
      if [ -e "$dev_dir/$f" ]; then has_state=1; fi
    done
    if [ "$has_state" = 1 ]; then
      mkdir -p "$dev_dir/state"
      for f in .claude .claude.json .bash_history; do
        if [ -e "$dev_dir/$f" ]; then
          mv "$dev_dir/$f" "$dev_dir/state/"
        fi
      done
      echo "Migrated state files into $dev_dir/state/" >&2
    fi
  fi

  if [ -f "$dev_dir/.env" ] && [ ! -f "$dev_dir/env" ]; then
    mv "$dev_dir/.env" "$dev_dir/env"
    echo "Renamed $dev_dir/.env to $dev_dir/env" >&2
  fi
}

run_migrations() {
  local dev_dir="$1"
  local current
  [ -d "$dev_dir" ] || return 0
  current=$(cat "$dev_dir/version" 2>/dev/null || echo 0)
  if [ "$current" -gt "$SCHEMA_VERSION" ]; then
    echo "Error: $dev_dir was written by a newer devcontainer.sh (schema v$current, this is v$SCHEMA_VERSION)" >&2
    echo "Update with: ./dev.sh --update" >&2
    exit 1
  fi
  while [ "$current" -lt "$SCHEMA_VERSION" ]; do
    case "$current" in
      0) migrate_v0_to_v1 "$dev_dir" ;;
    esac
    current=$((current + 1))
    echo "$current" > "$dev_dir/version"
  done
}

# --- Parse CLI flags ---

parse_flags "$@"
USER_CMD=("${PARSE_REMAINING[@]+"${PARSE_REMAINING[@]}"}")

WORKSPACE="${WORKSPACE:-.}"
if [[ ! -d "$WORKSPACE" ]]; then
  echo "Error: workspace directory '$WORKSPACE' does not exist" >&2
  exit 1
fi
DIR="$(cd "$WORKSPACE" && pwd)"
DEV_DIR="$DIR/.dev"
BASENAME="$(basename "$DIR")"
USES_DEVCONTAINER=false

# --- Migrate .dev/ layout if needed ---

run_migrations "$DEV_DIR"

# --- Load .dev/volumes and .dev/ports ---

load_lines "$DEV_DIR/volumes" -v
load_lines "$DEV_DIR/ports" -p

# --- Resolve Dockerfile ---

DOCKERFILE=""
if [ "$FORCE_BASE" = false ]; then
  if [ -f "$DEV_DIR/Dockerfile" ]; then
    DOCKERFILE="$DEV_DIR/Dockerfile"
  elif [ -f "$DIR/Dockerfile" ] && grep -q "^FROM.*ghcr\.io/bitlank/devcontainer" "$DIR/Dockerfile"; then
    DOCKERFILE="$DIR/Dockerfile"
    echo "warning: devcontainer Dockerfile in project root is deprecated — move it to .dev/Dockerfile" >&2
  fi
fi

# --- Build logic ---

if [ -n "$DOCKERFILE" ]; then
  CONTAINER="dev-${BASENAME}-$$"
  if grep -q "^FROM.*ghcr\.io/bitlank/devcontainer" "$DOCKERFILE"; then
    USES_DEVCONTAINER=true
    if [ "$BUILD" = true ] || ! docker image inspect "$BASE_IMAGE" >/dev/null 2>&1; then
      docker pull "$BASE_IMAGE"
    fi
  fi
  IMAGE="dev-${BASENAME}"
  if [ "$BUILD" = true ] || ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    docker build -t "$IMAGE" -f "$DOCKERFILE" "$DIR"
  fi
else
  CONTAINER="dev-base-${BASENAME}-$$"
  USES_DEVCONTAINER=true
  IMAGE="$BASE_IMAGE"
  if [ "$BUILD" = true ] || ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    docker pull "$IMAGE"
  fi
fi

# --- Mounts ---

DOCKER_ARGS+=(-v "$DIR:/workspace")

if [ "$USES_DEVCONTAINER" = true ]; then
  mkdir -p "$DEV_DIR/state/.claude"
  [ -f "$DEV_DIR/state/.claude.json" ]  || echo '{}' > "$DEV_DIR/state/.claude.json"
  [ -f "$DEV_DIR/state/.bash_history" ] || touch "$DEV_DIR/state/.bash_history"
  [ -f "$DEV_DIR/version" ] || echo "$SCHEMA_VERSION" > "$DEV_DIR/version"
  DOCKER_ARGS+=(
    -v "$DEV_DIR/state/.bash_history:/home/dev/.bash_history"
    -v "$DEV_DIR/state/.claude:/home/dev/.claude"
    -v "$DEV_DIR/state/.claude.json:/home/dev/.claude.json"
  )
fi

[ -f "$HOME/.gitconfig" ] && DOCKER_ARGS+=(--volume "$HOME/.gitconfig:/home/dev/.gitconfig:ro")
[ -f "$DEV_DIR/env" ] && DOCKER_ARGS+=(--env-file "$DEV_DIR/env")

# --- DinD (only for devcontainer-based images) ---

if [ "$USES_DEVCONTAINER" = true ]; then
  docker network create "$NETWORK" 2>/dev/null || true

  if ! docker ps --filter "name=^${DIND}$" --format '{{.ID}}' | grep -q .; then
    docker run -d --rm \
      --name "$DIND" \
      --network "$NETWORK" \
      --privileged \
      -e DOCKER_TLS_CERTDIR="" \
      -v devcontainer-dind-storage:/var/lib/docker \
      docker:dind
  fi

  cleanup() {
    if ! docker ps --filter "name=^dev-" --filter "status=running" \
         --format '{{.Names}}' | grep -qv "^${DIND}$"; then
      docker stop "$DIND" 2>/dev/null || true
      docker network rm "$NETWORK" 2>/dev/null || true
    fi
  }
  trap cleanup EXIT

  DOCKER_ARGS+=(--network "$NETWORK" -e "DOCKER_HOST=tcp://${DIND}:2375")
fi

# --- Run ---

TTY_FLAGS="-i"
[ -t 0 ] && TTY_FLAGS="-it"

docker run $TTY_FLAGS --rm --init \
  --name "$CONTAINER" \
  "${DOCKER_ARGS[@]}" \
  "$IMAGE" \
  "${USER_CMD[@]+"${USER_CMD[@]}"}"
