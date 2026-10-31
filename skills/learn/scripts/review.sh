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
echo; echo "== similar causes: open rows whose causes share most of their words (one cause worded differently; cluster by meaning from here) =="
python3 -I - "$DIR/inbox.md" "$since" <<'PYSIM'
import re, sys
STOP = set("the a an and or of to in on for with by from at as is are was were be been it its this that these those not no does did do when then than into only every each any all one two our their they them his her you your which what while after before same also".split())
def words(t):
    out = set()
    for w in re.findall(r"[a-z][a-z'-]+", t.lower()):
        w = w.strip("'-")
        if len(w) < 4 or w in STOP:
            continue
        for suf in ("ing", "ed", "es", "s"):
            if w.endswith(suf) and len(w) - len(suf) >= 4:
                w = w[: -len(suf)]
                break
        out.add(w)
    return out
rows = []
try:
    lines = open(sys.argv[1], encoding="utf-8").read().splitlines()
except OSError:
    lines = []
for line in lines:
    c = [x.strip() for x in line.split("|")]
    if len(c) < 10 or not re.match(r"20\d\d-\d\d-\d\d$", c[1]) or "open" not in c[8] or c[1] < sys.argv[2]:
        continue
    rows.append((c[2], c[5], words(c[5])))
groups = []  # complete linkage: a row joins a group only when it shares enough words with every row already in it
for r in rows:
    for g in groups:
        if all(len(r[2] & x[2]) >= 3 and len(r[2] & x[2]) / max(1, min(len(r[2]), len(x[2]))) >= 0.4 for x in g):
            g.append(r); break
    else:
        groups.append([r])
shown = 0
for g in sorted(groups, key=lambda g: (len({r[0] for r in g}), len(g)), reverse=True):
    if len(g) < 2:
        continue
    projects = sorted({r[0] for r in g})
    print("%2d rows, %d projects (%s):" % (len(g), len(projects), ", ".join(projects)))
    for r in g:
        print("     - %s" % r[1][:150])
    shown += 1
    if shown == 8:
        break
if not shown:
    print("   none")
PYSIM
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
