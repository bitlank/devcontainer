#!/usr/bin/env bash
# Remap the baked `dev` user to the host UID/GID so bind mounts are writable,
# then drop privileges and exec the container command.
set -euo pipefail

TARGET_UID="${HOST_UID:-$(id -u dev)}"
TARGET_GID="${HOST_GID:-$(id -g dev)}"

cur_uid="$(id -u dev)"
cur_gid="$(id -g dev)"

if [ "$TARGET_GID" != "$cur_gid" ]; then
  if getent group "$TARGET_GID" >/dev/null 2>&1; then
    # GID already owned by another group — keep image primary gid.
    TARGET_GID="$cur_gid"
  else
    groupmod -g "$TARGET_GID" dev
  fi
fi

if [ "$TARGET_UID" != "$cur_uid" ]; then
  usermod -u "$TARGET_UID" -g "$(id -g dev)" dev
fi

new_uid="$(id -u dev)"
new_gid="$(id -g dev)"
if [ "$new_uid" != "$cur_uid" ] || [ "$new_gid" != "$cur_gid" ]; then
  # -xdev: do not descend into bind mounts under /home/dev (e.g. .cursor, .claude, .codex).
  find /home/dev -xdev -exec chown -h "$new_uid:$new_gid" {} +
fi

# Seed home-only agent defaults when the bind-mounted state path is empty.
# System-policy tools (Codex, Claude) are installed under /etc at image build.
# Create as `dev` (already remapped to HOST_UID) so bind-mounted state dirs
# aren't left root-owned on the host.
seed_if_missing() {
  local src="$1" dest="$2"
  if [ ! -e "$dest" ]; then
    runuser -u dev -- mkdir -p "$(dirname "$dest")"
    runuser -u dev -- cp "$src" "$dest"
  fi
}

seed_if_missing \
  /usr/share/devcontainer/defaults/cursor/cli-config.json \
  /home/dev/.cursor/cli-config.json
seed_if_missing \
  /usr/share/devcontainer/defaults/cursor/workspace-trusted.json \
  /home/dev/.cursor/projects/workspace/.workspace-trusted

# Default to an interactive shell when CMD was cleared (e.g. a child image
# redeclared ENTRYPOINT, which resets CMD to empty in Docker).
if [ "$#" -eq 0 ]; then
  set -- bash
fi

exec runuser -u dev -- "$@"
