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

## Optional: custom Dockerfile

If your project needs extra dependencies, add a `Dockerfile` to the project root that extends the base image:

```dockerfile
FROM ghcr.io/bitlank/devcontainer:latest

RUN apt-get update && apt-get install -y <packages> \
    && rm -rf /var/lib/apt/lists/*
```

`dev.sh` detects this automatically and builds a layered child image. Without a `Dockerfile`, the base image is used as-is.

## Flags

Flags are passed through `dev.sh` to the underlying `devcontainer.sh`:

```
--build             Force rebuild / re-pull images
--base              Ignore project Dockerfile, use base image
--mount MOUNT       Pass a --mount to docker run
-v, --volume VOL    Pass a --volume to docker run
-p, --publish PORT  Pass a --publish to docker run
```
