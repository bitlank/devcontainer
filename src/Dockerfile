FROM ubuntu:24.04

# System packages
RUN apt-get update && apt-get install -y \
    unzip curl git sudo ca-certificates gnupg lsb-release \
    python3 python3-pip python3-venv \
    ripgrep jq vim file \
    netcat-openbsd dnsutils iputils-ping iproute2 net-tools \
    openssh-client bash-completion \
    && rm -rf /var/lib/apt/lists/*

# Node.js 22
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
       | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" \
       > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Docker CLI
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
       | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
       https://download.docker.com/linux/ubuntu noble stable" \
       > /etc/apt/sources.list.d/docker.list \
    && apt-get update && apt-get install -y docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

# uv (Python package runner, like npx for Python)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv
COPY --from=ghcr.io/astral-sh/uv:latest /uvx /usr/local/bin/uvx

# Claude Code
RUN npm install -g @anthropic-ai/claude-code@latest

# Lean `dev` user (UID/GID 1000, sudo only). Entrypoint remaps to the host
# UID/GID at start so bind-mounted project/state dirs are writable.
RUN userdel -r ubuntu || true \
    && groupdel ubuntu || true \
    && groupadd -g 1000 dev \
    && useradd -m -u 1000 -g 1000 -G sudo -s /bin/bash dev \
    && echo "dev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Silence Docker CLI "What's next" hints
ENV DOCKER_CLI_HINTS=false

WORKDIR /workspace
USER dev

# Cursor Agent CLI (installs to ~/.local; file store — no keychain in containers)
ENV PATH="/home/dev/.local/bin:${PATH}"
ENV AGENT_CLI_CREDENTIAL_STORE=file
RUN curl -fsSL https://cursor.com/install | bash \
    && agent --version

# Bash config (history file bind-mounted by devcontainer.sh)
RUN { \
      echo '[ -f /etc/bash_completion ] && source /etc/bash_completion'; \
      echo 'export PATH="$HOME/.local/bin:$PATH"'; \
      echo 'HISTSIZE=10000'; \
      echo 'HISTFILESIZE=20000'; \
      echo 'shopt -s histappend'; \
    } > /home/dev/.bashrc

# Entrypoint runs as root, remaps `dev`, then exec's the user command.
USER root
COPY dev-entrypoint.sh /usr/local/bin/dev-entrypoint.sh
RUN chmod +x /usr/local/bin/dev-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/dev-entrypoint.sh"]
CMD ["bash"]
