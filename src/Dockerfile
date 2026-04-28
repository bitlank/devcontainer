FROM ubuntu:24.04

# System packages
RUN apt-get update && apt-get install -y \
    unzip curl git sudo ca-certificates gnupg lsb-release \
    python3 python3-pip python3-venv \
    ripgrep jq vim \
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

# User
RUN useradd -m -s /bin/bash dev \
    && usermod -aG sudo dev \
    && echo "dev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

WORKDIR /workspace
USER dev

# Bash config (history file bind-mounted by devcontainer.sh)
RUN { \
      echo '[ -f /etc/bash_completion ] && source /etc/bash_completion'; \
      echo 'HISTSIZE=10000'; \
      echo 'HISTFILESIZE=20000'; \
      echo 'shopt -s histappend'; \
    } > /home/dev/.bashrc
