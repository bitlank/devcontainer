# devcontainer

Base devcontainer image + launcher scripts, published to GHCR and GitHub Releases.

## Layout

- `src/Dockerfile` — base image (`ghcr.io/bitlank/devcontainer:latest`): Ubuntu 26.04, Node 22, Python + uv, Docker CLI, Claude Code, Cursor Agent CLI. Lean `dev` user (UID 1000 + sudo); starts as root via entrypoint.
- `src/dev-entrypoint.sh` — remaps `dev` to `HOST_UID`/`HOST_GID` (groupmod only when GID free), `chown -xdev` on `/home/dev`, then `exec runuser -u dev`.
- `src/devcontainer.sh` — launcher that runs the image with a Docker-in-Docker sidecar. **Source of truth for the launcher.** Passes `HOST_UID`/`HOST_GID` from the host.
- `dev.sh` — thin bootstrap users curl into their project; downloads the latest `devcontainer.sh` release into `.dev/devcontainer.sh` and execs it.
- `.github/workflows/publish.yaml` — on tag `v*`: builds `src/` for linux/amd64+arm64, pushes to ghcr.io, attaches `src/devcontainer.sh` + `dev.sh` as release assets. No local build/test pipeline — publishing is tag-driven.
- `README.md` — user-facing docs for `.dev/` project customization (volumes/ports/env/Dockerfile). Read it before changing user-facing behavior.

## Editing rules

- **Never edit `.dev/devcontainer.sh`** — it's a downloaded copy that gets overwritten from the latest release. Edit `src/devcontainer.sh` instead.
- The rest of `.dev/` in this repo is transient dogfood state (this repo also uses its own devcontainer); treat as gitignored scratch.

## dind sidecar

Launcher lazily starts a shared `devcontainer-dind` container (volume `devcontainer-dind-storage`) and tears it down when the last `dev-*` container exits. Cold start backgrounds `docker system prune -af --filter "until=24h"` then `docker volume prune -af` (kept separate — Docker rejects `until=…` combined with `--volumes`).
