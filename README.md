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
-w, --workspace DIR  Project directory to mount (default: current directory)
--build              Force rebuild of the container image(s)
--mount MOUNT        Pass a --mount argument to docker run
-v, --volume VOL     Pass a --volume argument to docker run
-p, --publish PORT   Pass a --publish argument to docker run
-e, --env KEY=VAL    Pass an environment variable to the container
--env-file FILE      Pass an env file to the container
--base               Force use of the base devcontainer image (ignore project Dockerfile)

```
## Environment
variables in .dev/.env are always passed to docker.
