# devcontainer

Docker-based dev environment with Claude Code, Node.js, Python, and Docker-in-Docker.

## Quick start

Download `dev.sh` into your project root:

```bash
curl -fsSL https://github.com/bitlank/devcontainer/releases/latest/download/dev.sh -o dev.sh
chmod +x dev.sh
```

Launch a shell:

```bash
./dev.sh
```

This pulls `ghcr.io/bitlank/devcontainer:latest` and drops you into a container with `/workspace` mounted to your project directory. No other setup required.

Update the launcher script:

```bash
./dev.sh --update
```

## Project customization

All customization lives in `.dev/` inside your project. Nothing in the project root is touched.

```
.dev/
  Dockerfile        # optional, extends the base image
  volumes           # optional, one -v value per line
  ports             # optional, one -p value per line
  env               # optional, env file passed to docker
  state/            # per-user state (claude config, bash history) — gitignore
  version           # layout schema version (managed automatically)
  devcontainer.sh   # downloaded by dev.sh — gitignore
```

### `.dev/Dockerfile`

Add extra dependencies by extending the base image:

```dockerfile
FROM ghcr.io/bitlank/devcontainer:latest

RUN apt-get update && apt-get install -y <packages> \
    && rm -rf /var/lib/apt/lists/*
```

`dev.sh` detects it and builds a layered child image. Build context is the project root, so `COPY` paths are relative to it.

### `.dev/volumes` and `.dev/ports`

One value per line. Lines starting with `#` and blank lines are ignored. Each line becomes a `-v` or `-p` argument to `docker run`.

`.dev/volumes`:
```
# AWS creds
/home/me/.aws:/home/dev/.aws:ro

# Project data
/var/data:/data
```

`.dev/ports`:
```
3000
8080
5432
```

CLI flags are additive — `dev.sh -p 9000` adds 9000 on top of whatever is in `.dev/ports`. For advanced cases (`--mount type=...`, individual `-e VAR=val`), use the CLI directly or put them in `.dev/env`.

### `.dev/env`

Env file passed to docker via `--env-file`. Always loaded if present.

### `.dev/state/`

Per-user state mounted into the container (`~/.claude`, `~/.claude.json`, `~/.bash_history`). Don't commit this.

## Gitignore

Pick one:

**Share devcontainer setup with the team** — commit `Dockerfile`, `volumes`, `ports`, `version`; ignore the rest:

```gitignore
.dev/state/
.dev/env
.dev/devcontainer.sh
```

**Keep it fully local** — ignore the whole thing:

```gitignore
.dev/
```

## Flags

```
-w, --workspace DIR  Project directory to mount (default: current directory)
--build              Force rebuild of the container image(s)
--mount MOUNT        Pass a --mount argument to docker run
-v, --volume VOL     Pass a --volume argument to docker run
-p, --publish PORT   Pass a --publish argument to docker run
-e, --env KEY=VAL    Pass an environment variable to the container
--env-file FILE      Pass an env file to the container
--base               Force use of the base devcontainer image (ignore project Dockerfile)
```

## Migration from older layouts

If you have an older `.dev/` from before this layout, `dev.sh` migrates it automatically on first run:

- `.dev/.claude/`, `.dev/.claude.json`, `.dev/.bash_history` → `.dev/state/`
- `.dev/.env` → `.dev/env`
- A `Dockerfile` at the project root that extends the base image still works, but prints a deprecation warning. Move it to `.dev/Dockerfile`.

The schema version in `.dev/version` guards against running an older `dev.sh` against a `.dev/` written by a newer one.
