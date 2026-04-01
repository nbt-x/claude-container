FROM node:22-slim

# ── System dependencies ──────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl wget ca-certificates gnupg \
    build-essential python3 python3-pip python3-venv \
    jq ripgrep fd-find tree less vim nano \
    openssh-client \
    sudo \
    # Docker CLI dependencies
    apt-transport-https lsb-release \
    && rm -rf /var/lib/apt/lists/*

# ── Install Docker CLI + Compose plugin (for DinD support) ──────────
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg \
       -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) \
       signed-by=/etc/apt/keyrings/docker.asc] \
       https://download.docker.com/linux/debian \
       $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
       > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       docker-ce-cli docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# ── Install Claude Code globally ─────────────────────────────────────
RUN npm install -g @anthropic-ai/claude-code

# ── Create non-root user ─────────────────────────────────────────────
# node:22-slim ships a 'node' user at UID 1000; remove it first
ARG USER_UID=1000
ARG USER_GID=1000
RUN userdel -r node 2>/dev/null || true \
    && groupadd -g ${USER_GID} claude \
    && useradd -m -u ${USER_UID} -g ${USER_GID} -s /bin/bash claude \
    && echo "claude ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/claude

# ── Workspace directory ──────────────────────────────────────────────
RUN mkdir -p /workspace && chown claude:claude /workspace

# ── Switch to non-root user ──────────────────────────────────────────
USER claude
WORKDIR /workspace

COPY --chown=claude:claude entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["claude"]
