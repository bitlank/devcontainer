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

### `.dev/volumes`

One docker `-v` value per line; `#` for comments. Auto-generated on first run with state mounts and `~/.gitconfig`. Edit or comment out lines as needed.

Leading `~/` expands to `$HOME`, leading `./` to the project root. Missing host paths print a warning and are skipped.

```
./.dev/state/.bash_history:/home/dev/.bash_history
~/.gitconfig:/home/dev/.gitconfig:ro
/var/data:/data
```

### `.dev/ports`, `.dev/env`

`.dev/ports`: one `-p` value per line. `.dev/env`: docker env-file format. Both optional; CLI flags add on top of file contents.

### `.dev/state/`

Per-user state mounted into the container. Don't commit.

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
