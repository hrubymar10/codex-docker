# codex-docker

Run the [OpenAI Codex CLI](https://github.com/openai/codex) inside an isolated Docker container instead of directly on your host. The container mirrors your host environment (same paths, UID, shell), so file references, `AGENTS.md` discovery, sessions, and Codex auth all keep working with minimal friction.

This is the Codex sibling of [`claude-docker`](https://github.com/hrubymar10/claude-docker) and [`pi-docker`](https://github.com/hrubymar10/pi-docker): same general security model, same path-mirroring idea, but adapted to Codex's config and auth model.

## Features

- **Isolated execution** — codex runs in an Alpine container instead of directly on your host
- **Docker socket proxy** — filtered Docker API access via `wollomatic/socket-proxy` plus an extra validation proxy
- **Path mirroring** — `~/project` inside the container is the same path as on the host
- **Host identity mirroring** — same username, UID, home path, and preferred shell
- **Shared codex state** — mounts your `~/.codex/` directory, so auth, sessions, and config (`auth.json`, `config.toml`, history) are reused
- **Git safety rails** — blocks pushes to protected branches from inside the container
- **Optional GPG import** — import signing keys into the container at startup
- **Optional notifier hook** — mount a custom `codex-notifier` script into the container for sound/desktop notifications
- **Optional beeper helper** — host-side HTTP helper for simple sound notifications

## How it maps to Codex

Codex stores its state under `~/.codex/` (overridable via `CODEX_HOME`):

- `auth.json` — ChatGPT login or API key tokens
- `config.toml` — user settings
- `history.jsonl`, `log/`, session rollouts

`codex-docker` mounts that directory directly at the same path inside the container, so the same Codex identity and configuration are visible inside the container.

If you use a custom config path, set `CODEX_HOME` on the host before running `bin/codex-docker-ctrl start`.

## Prerequisites

- macOS or Linux
- Docker Desktop, OrbStack, or Docker Engine
- Node/npm on the build host is **not** required; the image installs Codex itself

## Setup

### 1. Clone and enter the repo

```bash
git clone https://github.com/hrubymar10/codex-docker.git
cd codex-docker
```

### 2. Add `bin/` to your PATH

```bash
export PATH="/path/to/codex-docker/bin:$PATH"
```

This gives you:

- `codex-docker`
- `codex-docker-ctrl`
- `codex-docker-vscode-wrapper`

### 3. Prepare Codex auth

You have two common options:

#### Option A: API key

Export an OpenAI API key on the host:

```bash
export OPENAI_API_KEY=sk-...
```

`codex-docker-ctrl` forwards `OPENAI_API_KEY` into the container if it's set on the host.

#### Option B: ChatGPT login

Codex stores OAuth/subscription auth in `~/.codex/auth.json`. Since that directory is mounted into the container, you can:

- authenticate on the host once with `codex login` (or use the existing browser flow), or
- authenticate inside the container after startup

### 4. Configure your project mounts

```bash
cp config/docker-compose.local.example.yml config/docker-compose.local.yml
```

Edit `config/docker-compose.local.yml` and add the directories you want Codex to access:

```yaml
services:
  codex:
    volumes:
      - ${HOST_HOME}/projects:${HOST_HOME}/projects
      - ${HOST_HOME}/work:${HOST_HOME}/work
```

Paths are mirrored exactly.

### 5. Optional: customize environment

```bash
cp config/.env.example config/.env
```

Useful for:

- pinning `CODEX_VERSION`
- selecting extra Alpine packages
- overriding `CODEX_HOME`
- setting protected branches

### 6. Start the container

```bash
bin/codex-docker-ctrl start
```

### 7. Use codex

From any mounted project directory:

```bash
cd ~/projects/my-app
codex-docker
```

Or:

```bash
bin/codex-docker-ctrl exec
```

Both run `codex` inside the container with the current working directory preserved.

For non-interactive / sandboxed runs, pass codex flags through:

```bash
codex-docker exec --dangerously-bypass-approvals-and-sandbox "summarize this repo"
```

(The container itself is already a sandbox; the `--dangerously-bypass-approvals-and-sandbox` flag tells Codex to skip its own internal sandbox + approval prompts when you've intentionally run it inside one.)

## VS Code

Most VS Code Codex extensions launch a configured `codex` binary. Point the extension at the wrapper in this repo so it uses the container instead:

```
/path/to/codex-docker/bin/codex-docker-vscode-wrapper
```

Make sure the container is running before launching the extension.

## Commands

```bash
bin/codex-docker-ctrl start          # build image, start container
bin/codex-docker-ctrl stop           # stop container
bin/codex-docker-ctrl status         # show status
bin/codex-docker-ctrl shell          # shell into the container
bin/codex-docker-ctrl exec           # run codex in the container
bin/codex-docker-ctrl rebuild        # rebuild image from scratch + restart
bin/codex-docker-ctrl beeper-start   # start host beeper server (default 127.0.0.1:9999)
bin/codex-docker-ctrl beeper-stop    # stop host beeper server

codex-docker                          # shortcut wrapper that runs codex in the container
```

Any codex arguments are forwarded:

```bash
codex-docker exec "summarize this repo"
codex-docker --model gpt-5
codex-docker --sandbox workspace-write
```

## Beeper

Optional host-side HTTP server (`beeper/main.go`) that plays a sound when called. Started by `codex-docker-ctrl beeper-start`. Two env vars control access:

- `BEEPER_BIND` — `host:port` to listen on. Default `127.0.0.1:9999`. Host must be an IP literal (no hostnames). Set to `0.0.0.0:9999` to expose on all interfaces.
- `BEEPER_ALLOW` — comma-separated list of source IPs / CIDRs that may call the beeper. Default `127.0.0.0/8`. Bare IPs are normalised to `/32` (v4) / `/128` (v6). Requests from anywhere else get a `403`.

For container access via `host.docker.internal`, the defaults are sufficient on Docker Desktop / OrbStack (it forwards to host loopback). For VPN clients or other remote access, widen both:

```bash
export BEEPER_BIND=0.0.0.0:9999
export BEEPER_ALLOW=127.0.0.0/8,172.28.47.0/24
```

**Linux note:** on Linux Docker Engine, `host.docker.internal` resolves to the Docker bridge gateway (typically in `172.17.0.0/16` or `172.16.0.0/12`), not host loopback. The default `BEEPER_ALLOW=127.0.0.0/8` will block those requests. Add the bridge subnet to the allowlist. Note: `beeper/main.go` calls `afplay` (macOS only) — sound playback does not work on Linux.

`X-Forwarded-For` is intentionally not honoured — this is a direct-connection service.

## Testing

```bash
bash -n bin/codex-docker bin/codex-docker-ctrl bin/codex-docker-vscode-wrapper bin/lib/session-cleanup.sh scripts/*.sh test/*.sh
make test
```

Current tests cover:

- mount boundary logic
- credential helper quoting
- session PID file naming
- wrapper behavior with mocked `docker`
- start-time preflight/override generation with mocked `docker`
- explicit compose project pinning (`COMPOSE_PROJECT_NAME`)
- `docker compose config` rendering smoke test
- VS Code wrapper forwarding

## Security

The container does **not** get direct access to `/var/run/docker.sock`.

Instead:

- Docker calls go through a filtering proxy
- dangerous container-create options are rejected
- Docker socket bind mounts are stripped from downstream create requests
- the in-container `docker` wrapper blocks dangerous subcommands like `run`, `build`, and `cp`
- the in-container `git` wrapper blocks pushes to protected branches (`main`, `master` by default)

See [SECURITY_ISSUES.md](SECURITY_ISSUES.md) for known limitations.

## Notes

- the notifier file is `config/codex-notifier`, mounted as `/usr/local/bin/codex-notifier`
- a compatibility symlink also exposes `/usr/local/bin/claude-notifier` inside the container for older scripts
- Codex reads `AGENTS.md`; `codex-docker-ctrl` auto-mounts your global `~/AGENTS.md` and `~/CLAUDE.md` if present
- `bin/codex-docker-ctrl` pins `COMPOSE_PROJECT_NAME=codex-docker` by default so docker resource names do not depend on the checkout directory name

## License

MIT
