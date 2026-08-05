# AGENTS.md

## Project

`codex-docker` runs the [OpenAI Codex CLI](https://github.com/openai/codex) inside a Docker container with host path mirroring, Docker socket filtering, and a few safety rails.

## Goals

- Keep codex isolated from the host except for explicitly mounted paths
- Preserve the same host paths, UID, username, and shell inside the container
- Reuse the host codex state directory (`~/.codex` by default; overridable via `CODEX_HOME`)
- Keep the implementation simple shell/compose/go where possible

## Important files

- `README.md` — user-facing setup and usage
- `Dockerfile` — container image, codex installation, tooling
- `docker-compose.yml` — main services and mounts
- `bin/codex-docker-ctrl` — lifecycle management (`start`, `stop`, `status`, `shell`, `exec`, `rebuild`, `beeper-*`)
- `bin/codex-docker` — convenience wrapper to run `codex` in the container
- `bin/codex-docker-vscode-wrapper` — wrapper for VS Code Codex extensions
- `bin/lib/session-cleanup.sh` — host-side session watchdog/cleanup
- `scripts/entrypoint.sh` — runtime setup inside the container
- `scripts/codex-session.sh` — in-container session wrapper
- `scripts/git-wrapper.sh` — blocks pushes to protected branches
- `scripts/docker-wrapper.sh` — allowlists safe Docker subcommands, including `build` and `buildx`, and warns on sibling sandbox image tags
- `scripts/go-install.sh` — Dockerfile helper to download Go by version
- `beeper/` — optional host-side HTTP beep server
- `../aws-ai-proxy/` - optional independently running AWS credential proxy consumed when `AWS_AI_PROXY_ENABLED` is true (https://github.com/hrubymar10/aws-ai-proxy)
- `docker-filter-proxy/` — extra validation layer in front of socket proxy
- `config/docker-compose.local.example.yml` — local mount template
- `config/.env.example` — environment template
- `test/test-codex-docker.sh` — lightweight host-side wrapper tests
- `test/test-vscode-wrapper.sh` — VS Code wrapper forwarding test
- `test/test-wrappers-mock.sh` — mocked `docker` tests for `codex-docker` and `codex-docker-ctrl`
- `test/test-preflight-overrides.sh` — preflight/override generation tests
- `test/test-compose-config.sh` — compose rendering smoke test

## Common commands

```bash
make test
make lint
bin/codex-docker-ctrl start
bin/codex-docker-ctrl status
bin/codex-docker-ctrl shell
bin/codex-docker-ctrl exec
bin/codex-docker-ctrl beeper-start
bin/codex-docker-ctrl beeper-stop
```

## Conventions

- Prefer small, direct shell scripts over heavy abstractions
- Keep codex-specific behavior in codex-specific files
- Backward compatibility is okay, but prefer codex-first names (`codex-notifier`, `CODEX_*` env vars, etc.)
- Keep `COMPOSE_PROJECT_NAME` pinned so docker resource names do not depend on the checkout directory name
- Docker repos are AWS proxy consumers only. Use `AWS_AI_PROXY_ENABLED` and `AWS_AI_PROXY_URL`; do not add proxy lifecycle management here.
- Legacy `AWS_CRED_PROXY_PROFILES` / `AWS_CRED_PROXY_PORT` values are ignored. `bin/codex-docker-ctrl start` and `rebuild` detect them when `AWS_AI_PROXY_ENABLED` is not truthy, prompt only on a TTY, and warn without blocking non-interactive runs.
- Update `README.md` when behavior changes
- Preserve exact host path mirroring semantics
- Preserve security defaults unless explicitly changing them

## Guardrails

- Do not add or update dependencies unless explicitly requested
- Do not weaken Docker/socket/git safety checks casually
- Do not mount more host paths by default than necessary
- If changing wrapper behavior, keep non-interactive/TTY behavior in mind

## Testing expectations

At minimum after meaningful changes:

```bash
bash -n bin/codex-docker bin/codex-docker-ctrl bin/codex-docker-vscode-wrapper bin/lib/session-cleanup.sh scripts/*.sh test/*.sh
make test
```

If changing compose/build logic, also verify:

```bash
docker compose -f docker-compose.yml config
```
