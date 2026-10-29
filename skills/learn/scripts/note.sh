#!/usr/bin/env bash
# Append one harness learning to the shared inbox (learn skill, section 1).
# Usage: note.sh <project> <phase> "<what happened>" "<root cause>" "<proposed change>" ["<evidence>"]
# Phase: spec | build | ux | qa | gates | deploy | report | company | portfolio | hire | tool
set -euo pipefail
[ $# -ge 5 ] || { sed -n '3,4p' "$0"; exit 2; }
DIR="${LEARNINGS_DIR:-$HOME/.agents/learnings}"; mkdir -p "$DIR"; f="$DIR/inbox.md"
[ -f "$f" ] || printf '# Learnings inbox\n\nOne row per harness friction, written by note.sh. Status: open | applied (date) | dropped (reason).\n\n| date | project | phase | what happened | root cause | proposed change | evidence | status |\n|---|---|---|---|---|---|---|---|\n' > "$f"
clean() { printf '%s' "$1" | tr '\n|' '  ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//'; }
cause="$(clean "$4")"
printf '| %s | %s | %s | %s | %s | %s | %s | open |\n' "$(date +%F)" "$(clean "$1")" "$(clean "$2")" "$(clean "$3")" "$cause" "$(clean "$5")" "$(clean "${6:-}")" >> "$f"
# Same root cause seen before? Key = its first three words, case-insensitive. 2 or more rows: promote it in the next review.
key="$(printf '%s' "$cause" | tr '[:upper:]' '[:lower:]' | awk '{print $1, $2, $3}' | sed -E 's/ +$//')"
n=$(grep -icF -- "$key" "$f" || true)
if [ "${n:-0}" -ge 2 ]; then echo "noted: '$key' seen $n times; promote it in the next learn review"; else echo "noted: first time for '$key'"; fi
