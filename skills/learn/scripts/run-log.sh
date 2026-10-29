#!/usr/bin/env bash
# Append one run's numbers to the shared runs log (learn skill, section 1).
# Usage: run-log.sh <project> <claude|codex> <verified> <total> <defects> <owner-actions> <reruns> <minutes> ["<note>"]
set -euo pipefail
[ $# -ge 8 ] || { sed -n '3p' "$0"; exit 2; }
DIR="${LEARNINGS_DIR:-$HOME/.agents/learnings}"; mkdir -p "$DIR"; f="$DIR/runs.log"
[ -f "$f" ] || echo '# date | project | tool | verified/total | defects | owner actions | reruns | minutes | note' > "$f"
note="$(printf '%s' "${9:-}" | tr '\n|' '  ')"
printf '%s | %s | %s | %s/%s | %s | %s | %s | %s | %s\n' "$(date +%F)" "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$note" >> "$f"
echo "logged run $(grep -c '^[0-9]' "$f") in $f"
