#!/usr/bin/env bash
set -euo pipefail

# ── Wait for Docker-in-Docker sidecar if DOCKER_HOST is set ──────────
if [[ -n "${DOCKER_HOST:-}" ]]; then
    echo "⏳ Waiting for Docker daemon (DinD sidecar)..."
    timeout=30
    while ! docker info >/dev/null 2>&1; do
        timeout=$((timeout - 1))
        if [[ $timeout -le 0 ]]; then
            echo "⚠️  Docker daemon not available — continuing without Docker support."
            break
        fi
        sleep 1
    done
    if docker info >/dev/null 2>&1; then
        echo "✅ Docker daemon is ready."
    fi
fi

# ── Execute the command (default: claude) ─────────────────────────────
exec "$@"
