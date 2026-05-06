#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

PASS=0; FAIL=0
ok()   { echo "  PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

echo
echo "═══ Mount boundary check ═══"
check_mount() {
  local workdir="$1" src="$2" expect="$3"
  if [[ "$workdir" == "$src" || "$workdir" == "$src/"* ]]; then result="match"; else result="nomatch"; fi
  if [[ "$result" == "$expect" ]]; then ok "'$workdir' vs '$src'"; else fail "'$workdir' vs '$src' → $result (expected $expect)"; fi
}
check_mount "$HOME/projects"     "$HOME/projects"  match
check_mount "$HOME/projects/sub" "$HOME/projects"  match
check_mount "${HOME}x"           "$HOME"           nomatch
check_mount "$HOME-evil"         "$HOME"           nomatch
check_mount "/etc/passwd"        "$HOME"           nomatch

echo
echo "═══ Credential helper: special chars ═══"
GIT_AUTH_USER="user'quotes" GIT_AUTH_TOKEN='pass$word!&' bash << 'BASH'
  printf '#!/bin/bash\nprintf "username=%%s\\npassword=%%s\\n" %s %s\n' \
    "$(printf '%q' "$GIT_AUTH_USER")" "$(printf '%q' "$GIT_AUTH_TOKEN")" > /tmp/test-cred-helper
BASH
chmod 700 /tmp/test-cred-helper
output=$(bash /tmp/test-cred-helper)
if [[ "$output" == $'username=user\'quotes\npassword=pass$word!&' ]]; then
  ok "cred helper: special chars (quotes, dollar, bang)"
else
  fail "cred helper special chars: got '$output'"
fi

GIT_AUTH_USER="bob" GIT_AUTH_TOKEN="simple-token" bash << 'BASH'
  printf '#!/bin/bash\nprintf "username=%%s\\npassword=%%s\\n" %s %s\n' \
    "$(printf '%q' "$GIT_AUTH_USER")" "$(printf '%q' "$GIT_AUTH_TOKEN")" > /tmp/test-cred-helper
BASH
chmod 700 /tmp/test-cred-helper
output=$(bash /tmp/test-cred-helper)
if [[ "$output" == $'username=bob\npassword=simple-token' ]]; then
  ok "cred helper: plain credentials"
else
  fail "cred helper plain: got '$output'"
fi
rm -f /tmp/test-cred-helper

echo
echo "═══ Session cleanup path ═══"
SESSION_ID="1234"
cat > /tmp/codex-session-cleanup-test.sh <<'BASH'
#!/bin/bash
f="/tmp/codex-session-${1}.pid"
echo $$ > "$f"
[[ -f "$f" ]]
BASH
chmod +x /tmp/codex-session-cleanup-test.sh
if /tmp/codex-session-cleanup-test.sh "$SESSION_ID" && [[ -f "/tmp/codex-session-${SESSION_ID}.pid" ]]; then
  ok "codex session pid file format"
else
  fail "codex session pid file format"
fi
rm -f "/tmp/codex-session-${SESSION_ID}.pid" /tmp/codex-session-cleanup-test.sh

echo
echo "═══ codex-session foreground exec ═══"
if grep -q '^exec codex "\$@"$' scripts/codex-session.sh; then
  ok "codex-session runs codex in the foreground"
else
  fail "codex-session missing foreground exec"
fi

echo
echo "═══ login shell PATH preservation ═══"
if grep -q 'COPY scripts/profile-path.sh   /etc/profile.d/codex-path.sh' Dockerfile; then
  ok "Dockerfile installs login-shell PATH fix"
else
  fail "Dockerfile missing login-shell PATH fix"
fi

if grep -q '/usr/local/go/bin' scripts/profile-path.sh && grep -q '/usr/local/custom-bin' scripts/profile-path.sh; then
  ok "profile PATH fix restores Go and custom bin locations"
else
  fail "profile PATH fix missing expected tool paths"
fi

echo
echo "═══════════════════════════════"
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && echo "ALL TESTS PASSED" || { echo "SOME TESTS FAILED"; exit 1; }
