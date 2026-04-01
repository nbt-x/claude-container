
Fully isolated, non-root Docker setup for [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview).  
One repo, one Dockerfile — spin up a fresh containerized Claude for every project.

This is a one-shot claude prompt - use this sh\*t at your own risk, or don't, I keep it public so I have it where I need it

## Quick Start

```bash
git clone <this-repo> claude-code-docker
cd claude-code-docker

cp .env.example .env
# Edit .env → set PROJECT_DIR to the project you want Claude to work on

docker compose run --rm claude
# Claude will prompt you to log in via browser on first launch
```

## How It Works

```
┌─────────────────────────────────────────────────────┐
│  Host                                               │
│                                                     │
│   ~/projects/my-app/  ◄──bind mount──┐              │
│                                      │              │
│  ┌───────────────────────────────────┼────────────┐ │
│  │  claude container (non-root)      │            │ │
│  │                                   ▼            │ │
│  │   /workspace  ← only mounted dir               │ │
│  │                                                │ │
│  │   Claude Code CLI (interactive login)          │ │
│  │   git, python3, build-essential, ripgrep, ...  │ │
│  │   sudo available (container-scoped only)       │ │
│  │                                                │ │
│  │   ┌──────────────────────────────────────────┐ │ │
│  │   │  optional DinD sidecar (--profile dind)  │ │ │
│  │   │  docker:27-dind  ← Claude can build/run  │ │ │
│  │   │  containers inside the container         │ │ │
│  │   └──────────────────────────────────────────┘ │ │
│  └────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

Authentication is intentionally ephemeral — Claude prompts you to log in via
browser each time you start a container. No tokens are stored on disk.

## Usage Patterns

### New project

```bash
git clone <this-repo> my-project-claude
cd my-project-claude
echo "PROJECT_DIR=/home/you/projects/my-project" > .env
docker compose run --rm claude
```

### Analyse an existing repo (e.g. SCA, code review)

Point `PROJECT_DIR` at any directory on your machine — your own repo, a
third-party checkout, anything:

```bash
git clone <this-repo> claude-sca
cd claude-sca

# Clone the target repo somewhere on the host
git clone https://github.com/some-org/target-repo /tmp/target-repo

echo "PROJECT_DIR=/tmp/target-repo" > .env
docker compose run --rm claude
# → "Review this codebase for known vulnerable dependencies"
```

Or skip the `.env` entirely with an inline override:

```bash
PROJECT_DIR=/tmp/target-repo docker compose run --rm claude
```

### Shared image, multiple projects

Build the image once:

```bash
git clone <this-repo> ~/claude-code-docker
cd ~/claude-code-docker
docker compose build
```

Then point it at different projects without cloning again:

```bash
PROJECT_DIR=~/projects/app-a  docker compose run --rm claude
PROJECT_DIR=~/projects/app-b  docker compose run --rm claude
PROJECT_DIR=/tmp/audit-target docker compose run --rm claude
```

## Docker-in-Docker

To let Claude build and run containers inside its own container (useful for
testing Dockerfiles, running test suites in containers, etc.):

```bash
docker compose --profile dind run --rm claude
```

This starts a `docker:27-dind` sidecar connected over TLS. Claude's container
gets a Docker CLI preconfigured to talk to it. Inside the Claude session:

```
$ docker run --rm hello-world   # works
$ docker compose up             # works
```

> **Note:** The DinD sidecar runs as `--privileged`. This is a Docker requirement
> for nested containers. The *Claude process itself* still runs as a non-root user.

## What's Inside the Container

| Tool | Why |
|---|---|
| `node 22` + `npm` | Claude Code runtime |
| `python3` + `pip` + `venv` | Python development |
| `git` | Version control |
| `build-essential` | Compiling native extensions |
| `ripgrep`, `fd-find`, `jq` | Fast code search and JSON processing |
| `curl`, `wget` | Fetching resources |
| `vim`, `nano` | Quick edits |
| `docker` CLI + compose | Talking to the DinD sidecar |
| `sudo` | Installing additional tools at runtime (container-scoped) |

Claude runs as user `claude` (UID 1000). Since `sudo` is available with
`NOPASSWD`, Claude can `sudo apt-get install` anything it needs — these changes
are ephemeral and scoped to the container.

## Security Model

- **Non-root process**: Claude runs as UID 1000, not root.
- **Single mount point**: Only `PROJECT_DIR` is visible at `/workspace`. No access
  to host home directory, SSH keys, Docker socket, or anything else.
- **No stored credentials**: You log in interactively each session. Auth state
  lives in the container's ephemeral filesystem and is gone when it stops.
- **Ephemeral container**: Installed packages, temp files, and caches vanish when
  the container stops. Only `/workspace` changes persist.
- **No host Docker socket**: Unlike many setups that mount `/var/run/docker.sock`,
  this uses a proper DinD sidecar — the host Docker daemon is never exposed.
- **Container-scoped sudo**: `sudo` inside the container cannot affect the host.

## Customization

### Adding tools to the image

Edit the `Dockerfile` and add packages to the `apt-get install` line, or add
new `RUN` layers. Rebuild with `docker compose build`.

### Changing the user UID/GID

If your project files are owned by a different UID on the host:

```bash
docker compose build --build-arg USER_UID=$(id -u) --build-arg USER_GID=$(id -g)
```

## File Structure

```
claude-code-docker/
├── Dockerfile          # Container image definition
├── entrypoint.sh       # Startup script (waits for DinD if active)
├── docker-compose.yml         # Docker Compose with optional DinD profile
├── .env.example        # Template — just set PROJECT_DIR
├── .dockerignore
├── .gitignore
└── README.md
```
