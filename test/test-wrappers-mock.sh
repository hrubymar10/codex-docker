#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"

PASS=0; FAIL=0
ok()   { echo "  PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT
FAKE_BIN="$TMP_ROOT/bin"
mkdir -p "$FAKE_BIN" "$TMP_ROOT/home" "$TMP_ROOT/work/project"
LOG="$TMP_ROOT/docker.log"
: > "$LOG"

cat > "$FAKE_BIN/docker" <<'EOF'
#!/bin/bash
set -euo pipefail
LOG_FILE="${FAKE_DOCKER_LOG:?}"
printf '%q ' "$@" >> "$LOG_FILE"
printf '\n' >> "$LOG_FILE"

case "${1:-}" in
  info)
    exit 0
    ;;
  inspect)
    format=""
    target=""
    args=("$@")
    for ((i=0; i<$#; i++)); do
      if [[ "${args[$i]}" == "--format" && $((i+1)) -lt $# ]]; then
        format="${args[$((i+1))]}"
      fi
    done
    for ((i=1; i<$#; i++)); do
      arg="${args[$i]}"
      if [[ "$arg" != "--format" && "$arg" != "$format" && "${args[$((i-1))]}" != "--format" ]]; then
        target="$arg"
        break
      fi
    done
    case "$format" in
      *'.Mounts'*)
        echo "${FAKE_DOCKER_MOUNT:?} "
        exit 0
        ;;
      *'{{.Name}}'*|*'.State.StartedAt'*)
        echo "Name: /$target  Status: running  Started: 2026-01-01T00:00:00Z"
        exit 0
        ;;
      *'.State.Status'*)
        case "$target" in
          codex-docker|codex-socket-proxy|codex-filter-proxy)
            echo running
            exit 0
            ;;
          *)
            exit 1
            ;;
        esac
        ;;
    esac
    exit 1
    ;;
  exec)
    if [[ "$*" == *'printenv CONTAINER_SHELL'* ]]; then
      echo /bin/zsh
      exit 0
    fi
    if [[ "$*" == *' codex-session '* || "$*" == *' codex-session' ]]; then
      echo codex-mock-0.0.0
      exit 0
    fi
    exit 0
    ;;
  *)
    echo "unexpected docker call: $*" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$FAKE_BIN/docker"

echo
echo "═══ mocked codex-docker wrapper ═══"
(
  export PATH="$FAKE_BIN:$PATH"
  export FAKE_DOCKER_LOG="$LOG"
  export FAKE_DOCKER_MOUNT="$TMP_ROOT/work"
  export CODEX_DOCKER_USER=tester
  cd "$TMP_ROOT/work/project"
  "$ROOT/bin/codex-docker" --version > "$TMP_ROOT/codex-docker.out"
)

if grep -Eq 'exec -i .*CODEX_SESSION_ID=.* -u tester -w .*/work/project codex-docker codex-session --dangerously-bypass-approvals-and-sandbox --version' "$LOG"; then
  ok "codex-docker forwards args and session env"
else
  fail "codex-docker did not emit expected docker exec call"
fi

if grep -Eq 'exec codex-docker sh -c .*codex-session-.*\.pid' "$LOG"; then
  ok "codex-docker performs cleanup exec"
else
  fail "codex-docker missing cleanup exec"
fi

if grep -q '^codex-mock-0.0.0$' "$TMP_ROOT/codex-docker.out"; then
  ok "codex-docker returns docker exec stdout"
else
  fail "codex-docker stdout mismatch"
fi

echo
echo "═══ mocked codex-docker-ctrl status ═══"
(
  export PATH="$FAKE_BIN:$PATH"
  export FAKE_DOCKER_LOG="$LOG"
  export FAKE_DOCKER_MOUNT="$TMP_ROOT/work"
  export HOME="$TMP_ROOT/home"
  "$ROOT/bin/codex-docker-ctrl" status > "$TMP_ROOT/status.out"
)

if grep -q '=== Socket Proxy ===' "$TMP_ROOT/status.out" \
  && grep -q '=== Filter Proxy ===' "$TMP_ROOT/status.out" \
  && grep -q '=== Container ===' "$TMP_ROOT/status.out" \
  && grep -q '=== Beeper ===' "$TMP_ROOT/status.out"; then
  ok "status prints expected sections"
else
  fail "status output missing sections"
fi

if grep -q 'Name: /codex-docker  Status: running' "$TMP_ROOT/status.out" \
  && grep -q 'Name: /codex-filter-proxy  Status: running' "$TMP_ROOT/status.out"; then
  ok "status reports running containers"
else
  fail "status output missing running container details"
fi

echo
echo "═══════════════════════════════"
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && echo "ALL TESTS PASSED" || { echo "SOME TESTS FAILED"; exit 1; }
