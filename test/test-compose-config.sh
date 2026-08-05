#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

PASS=0; FAIL=0
ok()   { echo "  PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

HOST_HOME="$TMP_ROOT/home/tester"
CODEX_HOME_DIR="$HOST_HOME/.codex"
GOPATH_DIR="$HOST_HOME/go"
mkdir -p "$CODEX_HOME_DIR" "$GOPATH_DIR/pkg"

OUT="$TMP_ROOT/compose-config.yml"

echo
echo "═══ docker compose config smoke test ═══"
HOST_UID=1000 \
HOST_USER=tester \
HOST_HOME="$HOST_HOME" \
GO_VERSION=go1.26.0 \
GOPATH="$GOPATH_DIR" \
CONTAINER_SHELL=/bin/bash \
EXTRA_PACKAGES= \
CODEX_VERSION= \
CODEX_HOME_HOST="$CODEX_HOME_DIR" \
ALLOWED_BIND_MOUNTS="$CODEX_HOME_DIR,$GOPATH_DIR/pkg" \
GITHUB_TOKEN=dummy \
GIT_USER_NAME= \
GIT_USER_EMAIL= \
GOPRIVATE= \
GONOSUMDB= \
docker compose -f docker-compose.yml config > "$OUT"

if grep -q '^  codex:$' "$OUT" && grep -q '^  filter-proxy:$' "$OUT" && grep -q '^  socket-proxy:$' "$OUT"; then
  ok "compose includes expected services"
else
  fail "compose missing expected services"
fi

if grep -q 'target: /usr/local/bin/codex-notifier' "$OUT"; then
  ok "compose mounts notifier hook"
else
  fail "compose missing notifier hook mount"
fi

if grep -q "source: $CODEX_HOME_DIR" "$OUT" && grep -q "target: $CODEX_HOME_DIR" "$OUT"; then
  ok "compose mounts codex home dir"
else
  fail "compose missing codex home dir mount"
fi

if grep -q 'container_name: codex-docker' "$OUT"; then
  ok "compose keeps expected container name"
else
  fail "compose missing codex-docker container name"
fi

if grep -Fq '|grpc|session.*|' "$OUT"; then
  ok "socket proxy allows BuildKit gRPC and session routes"
else
  fail "socket proxy missing BuildKit routes"
fi

echo
echo "═══════════════════════════════"
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && echo "ALL TESTS PASSED" || { echo "SOME TESTS FAILED"; exit 1; }
