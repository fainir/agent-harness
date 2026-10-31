#!/usr/bin/env bash
# Log one owner ask (a NEEDS YOU line) so the learn review can drive owner asks per run down (learn skill, section 2).
# Usage: owner-log.sh <project> <class> "<what was asked>" "<how to never ask this again, or unavoidable>" ["<what you staged>"]
# Class: sign-in | money | new-account | signature | identity | decision | physical | other
# Every ask except a decision is refused until it is staged (owner-actions step 3): the page, app or dialog where the
# owner acts is open and checked, everything around the click is done, and the fifth argument says so
# ("tabs open: ...; filled: ...", or why nothing can be opened).
set -euo pipefail
[ $# -ge 4 ] || { sed -n '3,4p' "$0"; exit 2; }
DIR="${LEARNINGS_DIR:-$HOME/.agents/learnings}"; mkdir -p "$DIR"; f="$DIR/owner-actions.log"
[ -f "$f" ] || echo '# date | project | class | what was asked | how to never ask again | staged' > "$f"
clean() { printf '%s' "$1" | tr '\n|' '  ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//'; }
class="$(clean "$2")"; staged="$(clean "${5:-}")"
# Web addresses in the ask; file names (README.md, app.json) are not pages to open.
sites="$(printf '%s' "$3" | tr 'A-Z' 'a-z' | sed -E 's/[^ ]+@[^ ]+//g' | grep -oE '([a-z0-9-]+\.)+[a-z]{2,}(/[^ ,;)]*)?' \
  | grep -vE '\.(md|json|jsonl|js|mjs|cjs|ts|tsx|py|sh|txt|html|css|yml|yaml|toml|png|jpe?g|gif|svg|plist|log|csv|lock|env|apk|pkg|dmg|zip|ipa|app)(/|$)' \
  | sort -u | tr '\n' ' ' | sed 's/ $//' || true)"
case "$(printf '%s' "$staged" | tr 'A-Z' 'a-z')" in ''|none|no|nothing|-|n/a) staged="" ;; esac
if [ "$class" != decision ] && [ -z "$staged" ]; then
  where="the page, app or dialog where the owner acts"; [ -n "$sites" ] && where="$sites"
  echo "not logged: stage this ask first (owner-actions step 3). Open $where in the owner's own browser or on their Mac (Claude in Chrome; Codex: its Chrome tool or open -a 'Google Chrome' <url>), check what it really asks for (the right URL, a Google or GitHub button or a password form), fill every field that is not a secret, payment detail or identity document, do every step before and after the click yourself, then run this again with a fifth argument naming what is open and filled, or why nothing can be opened." >&2
  exit 3
fi
printf '%s | %s | %s | %s | %s | %s\n' "$(date +%F)" "$(clean "$1")" "$class" "$(clean "$3")" "$(clean "$4")" "$staged" >> "$f"
month=$(date +%Y-%m); n=$(grep -c "^$month" "$f" || true)
k=$(grep "^$month" "$f" | awk -F'|' -v c="$class" '{x=$3; gsub(/^ +| +$/,"",x)} x==c' | wc -l | tr -d ' ')
echo "owner asks this month: ${n:-0} (${k:-0} of class '$class'); the learn review tries to remove the top class"
