#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"

PASS=0; FAIL=0
ok()   { echo "  PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

TMP_ROOT=$(mktemp -d)
LOG="$TMP_ROOT/codex-docker.log"
mkdir -p "$TMP_ROOT/bin"

cat > "$TMP_ROOT/bin/codex-docker" <<'EOF'
#!/bin/bash
printf '%q ' "$@" >> "$CODEX_DOCKER_WRAPPER_LOG"
printf '\n' >> "$CODEX_DOCKER_WRAPPER_LOG"
echo wrapped-ok
EOF
chmod +x "$TMP_ROOT/bin/codex-docker"

# Swap the sibling codex-docker binary so the wrapper resolves to the fake.
ORIG="$ROOT/bin/codex-docker"
BAK="$TMP_ROOT/codex-docker.bak"
cp "$ORIG" "$BAK"
cp "$TMP_ROOT/bin/codex-docker" "$ORIG"
trap 'cp "$BAK" "$ORIG"; rm -rf "$TMP_ROOT"' EXIT

echo
echo "═══ vscode wrapper forwarding ═══"
CODEX_DOCKER_WRAPPER_LOG="$LOG" "$ROOT/bin/codex-docker-vscode-wrapper" --arg1 hello world > "$TMP_ROOT/out.txt"

if grep -Eq '^--arg1 hello world $' "$LOG"; then
  ok "vscode wrapper forwards argv unchanged"
else
  fail "vscode wrapper argv mismatch"
fi

if grep -q '^wrapped-ok$' "$TMP_ROOT/out.txt"; then
  ok "vscode wrapper returns delegated stdout"
else
  fail "vscode wrapper stdout mismatch"
fi

echo
echo "═══════════════════════════════"
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && echo "ALL TESTS PASSED" || { echo "SOME TESTS FAILED"; exit 1; }
