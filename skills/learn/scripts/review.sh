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
echo; echo "== project lessons in 2 or more projects (promotion candidates for the shared harness) =="
python3 -I - ${PROJECT_ROOTS:-"$HOME/Documents/GitHub"} <<'PYEOF2'
import glob, os, re, sys
seen = {}
for root in sys.argv[1:]:
    for f in glob.glob(os.path.join(root, "*", "AGENTS.md")) + glob.glob(os.path.join(root, "*", "*", "AGENTS.md")):
        proj = os.path.relpath(os.path.dirname(f), root)
        text = open(f, encoding="utf-8", errors="ignore").read()
        m = re.search(r"^## Working here\n(.*?)(?=^## |\Z)", text, re.S | re.M)
        if not m:
            continue
        for line in m.group(1).splitlines():
            if not line.startswith("- "):
                continue
            words = re.findall(r"[a-z0-9]+", line.lower())[:5]
            key = " ".join(w for w in words if len(w) > 3)[:60]
            if key:
                seen.setdefault(key, {})[proj] = line[2:120]
hits = [(k, v) for k, v in seen.items() if len(v) >= 2]
for k, v in sorted(hits, key=lambda kv: -len(kv[1]))[:10]:
    print("%2d  %s  -> %s" % (len(v), next(iter(v.values())), ", ".join(sorted(v))))
if not hits:
    print("   none yet")
PYEOF2
echo; echo "== last 5 applied changes =="
grep '^| 20' "$DIR/applied.md" 2>/dev/null | tail -5
echo; echo "== size budget =="
bash "$(dirname "$0")/size.sh" || echo "over budget: simplify before adding anything"
