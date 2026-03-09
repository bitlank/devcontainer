#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
BASE_IMAGE="ghcr.io/bitlank/devcontainer:latest"

NETWORK="devcontainer-net"
DIND="devcontainer-dind"
BUILD=false
DOCKER_ARGS=()

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
  --base               Force use of the base devcontainer image (ignore project Dockerfile)
  -h, --help           Show this help message

Arguments:
  COMMAND...           Command to run inside the container (default: interactive shell)

If the workspace contains a Dockerfile that extends the devcontainer base image,
a layered child image is built automatically. Otherwise the base devcontainer
image is used.
EOF
}

# Parse flags
FORCE_BASE=false
WORKSPACE=""
while [[ "${1:-}" == --* || "${1:-}" == -?* ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -w|--workspace)
      if [ -n "$WORKSPACE" ]; then
        echo "Error: --workspace specified more than once" >&2
        exit 1
      fi
      WORKSPACE="$2"; shift 2 ;;
    --base) FORCE_BASE=true; shift ;;
    --build) BUILD=true; shift ;;
    --mount) DOCKER_ARGS+=(--mount "$2"); shift 2 ;;
    -v|--volume) DOCKER_ARGS+=(--volume "$2"); shift 2 ;;
    -p|--publish) DOCKER_ARGS+=(--publish "$2"); shift 2 ;;
    *) echo "Unknown option: $1" >&2; echo >&2; usage >&2; exit 1 ;;
  esac
done

WORKSPACE="${WORKSPACE:-.}"

if [[ ! -d "$WORKSPACE" ]]; then
  echo "Error: workspace directory '$WORKSPACE' does not exist" >&2
  exit 1
fi
DIR="$(cd "$WORKSPACE" && pwd)"

BASENAME="$(basename "$DIR")"
USES_DEVCONTAINER=false

# --- Build logic ---

if [ "$FORCE_BASE" = false ] && [ -f "$DIR/Dockerfile" ]; then
  CONTAINER="dev-${BASENAME}"
  # Project has its own Dockerfile
  if grep -q "^FROM.*ghcr\.io/bitlank/devcontainer" "$DIR/Dockerfile"; then
    # Child of devcontainer — pull base first
    USES_DEVCONTAINER=true
    if [ "$BUILD" = true ] || ! docker image inspect "$BASE_IMAGE" >/dev/null 2>&1; then
      docker pull "$BASE_IMAGE"
    fi
  fi
  IMAGE="dev-${BASENAME}"
  if [ "$BUILD" = true ] || ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    docker build -t "$IMAGE" "$DIR"
  fi
else
  # No Dockerfile — use base devcontainer directly
  CONTAINER="dev-base-${BASENAME}"
  USES_DEVCONTAINER=true
  IMAGE="$BASE_IMAGE"
  if [ "$BUILD" = true ] || ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    docker pull "$IMAGE"
  fi
fi

# --- Mounts ---

DOCKER_ARGS+=(-v "$DIR:/workspace")

# Dev state (claude config, bash history) only for devcontainer-based images
if [ "$USES_DEVCONTAINER" = true ]; then
  DEV_DIR="$DIR/.dev"
  mkdir -p "$DEV_DIR/.claude"
  [ -f "$DEV_DIR/.claude.json" ] || echo '{}' > "$DEV_DIR/.claude.json"
  [ -f "$DEV_DIR/.bash_history" ] || touch "$DEV_DIR/.bash_history"
  DOCKER_ARGS+=(
    -v "$DEV_DIR/.bash_history:/home/dev/.bash_history"
    -v "$DEV_DIR/.claude:/home/dev/.claude"
    -v "$DEV_DIR/.claude.json:/home/dev/.claude.json"
  )
fi

[ -f "$HOME/.gitconfig" ] && DOCKER_ARGS+=(--volume "$HOME/.gitconfig:/home/dev/.gitconfig:ro")

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

if [ $# -eq 0 ]; then
  docker run -it --rm \
    --name "$CONTAINER" \
    "${DOCKER_ARGS[@]}" \
    "$IMAGE"
else
  TTY_FLAGS="-i"
  [ -t 0 ] && TTY_FLAGS="-it"
  docker run $TTY_FLAGS --rm \
    --name "$CONTAINER" \
    "${DOCKER_ARGS[@]}" \
    "$IMAGE" \
    "$@"
fi
