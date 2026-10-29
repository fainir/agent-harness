#!/usr/bin/env bash
# Inputs for a learn review (learn skill, section 2): open learnings grouped by root cause, recent runs, applied changes, size budget.
# Usage: review.sh [days]   (default 30)
set -uo pipefail
DIR="${LEARNINGS_DIR:-$HOME/.agents/learnings}"; days="${1:-30}"
since=$(date -v-"${days}d" +%F 2>/dev/null || date -d "-${days} days" +%F)
echo "== open learnings since $since, grouped by root cause: count, cause, projects =="
awk -F'|' -v s="$since" '
  $9 ~ /open/ && $2 ~ /20[0-9][0-9]-/ {
    d=$2; gsub(/ /,"",d); if (d < s) next
    c=$6; gsub(/^ +| +$/,"",c); split(tolower(c), w, " "); k=w[1] " " w[2] " " w[3]
    n[k]++; if (index(p[k], $3) == 0) p[k]=p[k] $3; e[k]=c }
  END { for (k in n) printf "%2d  %s  ->%s\n", n[k], e[k], p[k] }' "$DIR/inbox.md" 2>/dev/null | sort -rn | head -20
echo; echo "== last 10 runs (date | project | tool | verified/total | defects | owner | reruns | minutes | note) =="
grep '^[0-9]' "$DIR/runs.log" 2>/dev/null | tail -10
echo; echo "== owner load: asks since $since by class (owner-actions.log) =="
awk -F'|' -v s="$since" '$1 ~ /^20[0-9][0-9]-/ { d=$1; gsub(/ /,"",d); if (d >= s) { c=$3; gsub(/^ +| +$/,"",c); n[c]++ } } END { for (c in n) printf "%2d  %s\n", n[c], c }' "$DIR/owner-actions.log" 2>/dev/null | sort -rn
echo "-- how to never ask again (last 8 ideas):"
awk -F'|' -v s="$since" '$1 ~ /^20[0-9][0-9]-/ { d=$1; gsub(/ /,"",d); if (d >= s && $5 !~ /unavoidable/) print "   -" $5 " (" $3 ", " $2 ")" }' "$DIR/owner-actions.log" 2>/dev/null | tail -8
echo "-- owner asks per run (runs.log, older half vs newer half):"
grep '^[0-9]' "$DIR/runs.log" 2>/dev/null | awk -F'|' '{ v[NR] = $7 + 0 } END { if (NR < 2) { print "   not enough runs"; exit } h = int(NR / 2); for (i = 1; i <= h; i++) a += v[i]; for (i = h + 1; i <= NR; i++) b += v[i]; printf "   %.1f -> %.1f per run (%d runs)\n", a / h, b / (NR - h), NR }'
echo; echo "== last 5 applied changes =="
grep '^| 20' "$DIR/applied.md" 2>/dev/null | tail -5
echo; echo "== size budget =="
bash "$(dirname "$0")/size.sh" || echo "over budget: simplify before adding anything"
