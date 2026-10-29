#!/usr/bin/env bash
# One headless worker per active company in PORTFOLIO.md, in parallel, bounded by MAX_ACTIVE.
# Each worker runs "continue" in its company folder; the ship or run-company skill there takes the next row.
# Usage: tick.sh [portfolio-dir]
# Env:   RUNNER=claude|codex (default claude)  MAX_ACTIVE=5  PROMPT="continue"  TIMEOUT=2400 (seconds per worker)
#        STAGES="validating building launched growing"  CLAUDE_FLAGS  CODEX_FLAGS
#        TICK_KEEP_ENV_AUTH=1 keeps an inherited ANTHROPIC_API_KEY when run inside a Claude Code session (see below)
set -uo pipefail

ROOT="$(cd "${1:-.}" && pwd)"; cd "$ROOT"
[ -f PORTFOLIO.md ] || { echo "no PORTFOLIO.md in $ROOT" >&2; exit 1; }
RUNNER="${RUNNER:-claude}"; MAX_ACTIVE="${MAX_ACTIVE:-5}"; PROMPT="${PROMPT:-continue}"; TIMEOUT="${TIMEOUT:-2400}"
STAGES="${STAGES:-validating building launched growing}"
CLAUDE_FLAGS="${CLAUDE_FLAGS:---permission-mode bypassPermissions}"
CODEX_FLAGS="${CODEX_FLAGS:---profile build --dangerously-bypass-approvals-and-sandbox --dangerously-bypass-hook-trust --skip-git-repo-check}"
# Inside a Claude Code session (desktop app or CLI) the shell carries that session's own ANTHROPIC_API_KEY and
# ANTHROPIC_BASE_URL, which expire with the session. Workers must use the CLI's own login (claude auth login) instead.
if [ "${CLAUDECODE:-}" = 1 ] && [ "${TICK_KEEP_ENV_AUTH:-0}" != 1 ]; then unset ANTHROPIC_API_KEY ANTHROPIC_BASE_URL; fi
STAMP="$(date +%Y%m%d-%H%M)"; mkdir -p .runtime/ticks
LOCK_MIN=$(( TIMEOUT / 60 )); [ "$LOCK_MIN" -gt 0 ] || LOCK_MIN=1

# Companies table rows look like: | P3 | Name | companies/slug | building | ... |
active=()
while IFS='|' read -r _ id _name folder stage _rest; do
  id="$(echo "${id:-}" | xargs)"; folder="$(echo "${folder:-}" | xargs)"; stage="$(echo "${stage:-}" | xargs | cut -d' ' -f1)"
  case "$id" in P[0-9]*) ;; *) continue ;; esac
  case " $STAGES " in *" $stage "*) ;; *) continue ;; esac
  [ -d "$folder" ] || { echo "skip  $id: folder '$folder' missing"; continue; }
  active+=("$id|$folder")
done < PORTFOLIO.md
[ "${#active[@]}" -gt 0 ] || { echo "nothing active (stages: $STAGES)"; exit 0; }

pids=(); dogs=(); logs=(); ids=(); n=0
for entry in "${active[@]}"; do
  id="${entry%%|*}"; folder="${entry#*|}"
  if [ "$n" -ge "$MAX_ACTIVE" ]; then echo "queue $id (max active $MAX_ACTIVE)"; continue; fi
  lock="$folder/.runtime/tick.lock"; mkdir -p "$folder/.runtime"
  if [ -e "$lock" ] && [ -z "$(find "$lock" -mmin +"$LOCK_MIN" 2>/dev/null)" ]; then echo "busy  $id ($lock)"; continue; fi
  echo "$STAMP $$" > "$lock"
  log=".runtime/ticks/$id-$STAMP.log"
  (
    cd "$folder" || exit 1
    if [ "$RUNNER" = codex ]; then exec codex exec $CODEX_FLAGS "$PROMPT"; else exec claude -p "$PROMPT" $CLAUDE_FLAGS; fi
  ) > "$log" 2>&1 < /dev/null &
  pid=$!
  # Watchdog: detached stdio so it never holds a pipe open; its sleep is killed with it below.
  ( sleep "$TIMEOUT"; kids=$(pgrep -P "$pid" 2>/dev/null); kill "$pid" 2>/dev/null && echo "[tick] killed after ${TIMEOUT}s" >> "$log"; [ -n "$kids" ] && kill $kids 2>/dev/null ) > /dev/null 2>&1 < /dev/null &
  dog=$!; disown "$dog" 2>/dev/null
  dogs+=("$dog"); pids+=("$pid"); logs+=("$log"); ids+=("$id"); n=$((n + 1))
  echo "start $id -> $folder ($RUNNER, log $log)"
done

for i in "${!pids[@]}"; do
  { wait "${pids[$i]}"; rc=$?; } 2>/dev/null
  pkill -P "${dogs[$i]}" 2>/dev/null; kill "${dogs[$i]}" 2>/dev/null
  folder="${active[$i]#*|}"
  for e in "${active[@]}"; do [ "${e%%|*}" = "${ids[$i]}" ] && folder="${e#*|}"; done
  rm -f "$folder/.runtime/tick.lock"
  printf '\n== %s (exit %s) ==\n' "${ids[$i]}" "$rc"; tail -n 6 "${logs[$i]}"
  printf '%s %s exit %s %s\n' "$STAMP" "${ids[$i]}" "$rc" "${logs[$i]}" >> .runtime/ticks/summary.log
done
echo; echo "tick done: $n workers ($RUNNER). Read the logs, update PORTFOLIO.md, report."
