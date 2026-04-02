#!/usr/bin/env bash
set -euo pipefail

# ── Wait for Docker-in-Docker sidecar if DOCKER_HOST is set ──────────
if [[ -n "${DOCKER_HOST:-}" ]]; then
    echo "⏳ Waiting for Docker daemon (DinD sidecar)..."
    retries=10
    while ! timeout 2 docker info >/dev/null 2>&1; do
        retries=$((retries - 1))
        if [[ $retries -le 0 ]]; then
            echo "⚠️  Docker daemon not available — clearing Docker env vars."
            unset DOCKER_HOST
            unset DOCKER_TLS_VERIFY
            unset DOCKER_CERT_PATH
            break
        fi
        sleep 1
    done
    if [[ -n "${DOCKER_HOST:-}" ]]; then
        echo "✅ Docker daemon is ready."
    fi
fi

# ── Execute the command (default: claude) ─────────────────────────────
exec "$@"
