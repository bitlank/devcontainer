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

exec runuser -u dev -- "$@"
