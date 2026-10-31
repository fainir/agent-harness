#!/usr/bin/env bash
# Append one harness learning to the shared inbox (learn skill, section 1).
# Usage: note.sh <project> <phase> "<what happened>" "<root cause>" "<proposed change>" ["<evidence>"]
#        note.sh "<one line>"   (quick form: project = this repo or folder, phase tool, the line is also the root cause)
# Phase: spec | build | ux | qa | gates | deploy | report | company | portfolio | hire | tool
set -euo pipefail
if [ $# -eq 1 ]; then  # the rules say "one note.sh line"; take it rather than drop the lesson
  top="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; set -- "$(basename "$top")" tool "$1" "$1" "decide in the review"
fi
[ $# -ge 5 ] || { sed -n '3,5p' "$0" >&2; exit 2; }
DIR="${LEARNINGS_DIR:-$HOME/.agents/learnings}"; mkdir -p "$DIR"; f="$DIR/inbox.md"
[ -f "$f" ] || printf '# Learnings inbox\n\nOne row per harness friction, written by note.sh. Status: open | applied (date) | dropped (reason).\n\n| date | project | phase | what happened | root cause | proposed change | evidence | status |\n|---|---|---|---|---|---|---|---|\n' > "$f"
clean() { printf '%s' "$1" | tr '\n|' '  ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//'; }
cause="$(clean "$4")"
printf '| %s | %s | %s | %s | %s | %s | %s | open |\n' "$(date +%F)" "$(clean "$1")" "$(clean "$2")" "$(clean "$3")" "$cause" "$(clean "$5")" "$(clean "${6:-}")" >> "$f"
# Same root cause seen before? Counted by meaning (similar.py: 3 shared words and 40 percent), so a cause reworded by
# another session still counts and two causes that only open alike do not. 2 or more open rows: promote it in the review.
read -r n projects <<<"$(python3 -I "$(dirname "$0")/similar.py" count "$f" "$cause" 2>/dev/null || echo 1)"
short="$(printf '%s' "$cause" | cut -c1-60)"
if [ "${n:-1}" -ge 2 ]; then echo "noted: '$short' seen $n times (${projects}); promote it in the next learn review"; else echo "noted: first time for '$short'"; fi
