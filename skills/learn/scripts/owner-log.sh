#!/usr/bin/env bash
# Log one owner ask (a NEEDS YOU line) so the learn review can drive owner asks per run down (learn skill, section 2).
# Usage: owner-log.sh <project> <class> "<what was asked>" "<how to never ask this again, or unavoidable>"
# Class: sign-in | money | new-account | signature | identity | decision | physical | other
set -euo pipefail
[ $# -ge 4 ] || { sed -n '3,4p' "$0"; exit 2; }
DIR="${LEARNINGS_DIR:-$HOME/.agents/learnings}"; mkdir -p "$DIR"; f="$DIR/owner-actions.log"
[ -f "$f" ] || echo '# date | project | class | what was asked | how to never ask again' > "$f"
clean() { printf '%s' "$1" | tr '\n|' '  ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//'; }
class="$(clean "$2")"
printf '%s | %s | %s | %s | %s\n' "$(date +%F)" "$(clean "$1")" "$class" "$(clean "$3")" "$(clean "$4")" >> "$f"
month=$(date +%Y-%m); n=$(grep -c "^$month" "$f" || true)
k=$(grep "^$month" "$f" | awk -F'|' -v c="$class" '{x=$3; gsub(/^ +| +$/,"",x)} x==c' | wc -l | tr -d ' ')
echo "owner asks this month: ${n:-0} (${k:-0} of class '$class'); the learn review tries to remove the top class"
