#!/usr/bin/env bash
# One headless run of the harness in a company, product or portfolio folder: "continue" takes the next
# ledger row. Used by schedule.sh (launchd or cron) and by hand. One run at a time per folder (lock),
# bounded by TIMEOUT, logs under .runtime/runs/.
# Usage: run.sh [dir]
# Env:   RUNNER=claude|codex (default claude)  PROMPT="continue"  TIMEOUT=2400 (seconds)  CLAUDE_FLAGS  CODEX_FLAGS
set -uo pipefail
DIR="$(cd "${1:-.}" && pwd)"; cd "$DIR" || exit 1
RUNNER="${RUNNER:-claude}"; PROMPT="${PROMPT:-continue}"; TIMEOUT="${TIMEOUT:-2400}"
CLAUDE_FLAGS="${CLAUDE_FLAGS:---permission-mode bypassPermissions --no-session-persistence}"
CODEX_FLAGS="${CODEX_FLAGS:---profile build --dangerously-bypass-approvals-and-sandbox --dangerously-bypass-hook-trust --skip-git-repo-check}"
# Inside a Claude Code session the shell carries that session's own expiring token; workers use the CLI login.
if [ "${CLAUDECODE:-}" = 1 ] && [ "${TICK_KEEP_ENV_AUTH:-0}" != 1 ]; then unset ANTHROPIC_API_KEY ANTHROPIC_BASE_URL; fi
ledger=""; for f in READINESS.md COMPANY.md PORTFOLIO.md; do [ -f "$f" ] && { ledger="$f"; break; }; done
[ -n "$ledger" ] || { echo "no ledger (READINESS.md, COMPANY.md or PORTFOLIO.md) in $DIR" >&2; exit 1; }
mkdir -p .runtime/runs; lock=.runtime/run.lock; LOCK_MIN=$(( TIMEOUT / 60 )); [ "$LOCK_MIN" -gt 0 ] || LOCK_MIN=1
if [ -e "$lock" ] && [ -z "$(find "$lock" -mmin +"$LOCK_MIN" 2>/dev/null)" ]; then echo "busy: $lock is fresh, another run is on"; exit 0; fi
STAMP="$(date +%Y%m%d-%H%M)"; log=".runtime/runs/$STAMP.log"; echo "$STAMP $$" > "$lock"
(
  if [ "$RUNNER" = codex ]; then exec codex exec $CODEX_FLAGS "$PROMPT"; else exec claude -p "$PROMPT" $CLAUDE_FLAGS; fi
) > "$log" 2>&1 < /dev/null &
pid=$!
( sleep "$TIMEOUT"; kids=$(pgrep -P "$pid" 2>/dev/null); kill "$pid" 2>/dev/null && echo "[run] killed after ${TIMEOUT}s" >> "$log"; [ -n "$kids" ] && kill $kids 2>/dev/null ) > /dev/null 2>&1 < /dev/null &
dog=$!; disown "$dog" 2>/dev/null
{ wait "$pid"; rc=$?; } 2>/dev/null
pkill -P "$dog" 2>/dev/null; kill "$dog" 2>/dev/null; rm -f "$lock"
printf '%s %s %s exit %s %s\n' "$STAMP" "$ledger" "$RUNNER" "$rc" "$log" >> .runtime/runs/summary.log
ls -t .runtime/runs/*.log 2>/dev/null | tail -n +31 | xargs rm -f 2>/dev/null
echo "== $ledger run $STAMP ($RUNNER, exit $rc) =="; tail -n 8 "$log"
exit "$rc"
