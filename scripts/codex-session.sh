#!/bin/sh
# Wrapper that ensures codex + children are killed when the session ends.
#
# Defense in depth — two cleanup mechanisms:
#
# 1. Container-side: trap on signals kills the process group. Works when
#    signals are delivered explicitly (e.g. host-side wrapper sends SIGHUP).
#
# 2. Host-side: the caller (bin/codex-docker) passes CODEX_SESSION_ID env var.
#    This script writes its PID to a known file. When docker exec exits on the
#    host, the caller reads the PID file and sends SIGHUP to the process group.

if [ -n "$CODEX_SESSION_ID" ]; then
    echo $$ > "/tmp/codex-session-${CODEX_SESSION_ID}.pid"
fi

# Run codex in the foreground so it keeps terminal control. We still write the
# pid file above, and the host-side wrapper sends SIGHUP to that pid on cleanup.
exec codex "$@"
