#!/usr/bin/env bash
# Turn an idea into a company folder and a PORTFOLIO.md row. Run from the portfolio root.
# Usage: new-company.sh <slug> "<Name>" "<one sentence: what, for whom, who pays, why now>"
set -euo pipefail

SLUG="${1:?slug}"; NAME="${2:?name}"; IDEA="${3:-}"
SKILLS="$(cd "$(dirname "$0")/../.." && pwd)"
[ -f PORTFOLIO.md ] || { echo "run from the portfolio root (PORTFOLIO.md missing)" >&2; exit 1; }
TODAY="$(date +%Y-%m-%d)"
DIR="companies/$SLUG"
THESIS="$(grep -m1 '^Thesis:' PORTFOLIO.md | sed 's/^Thesis: *//')"

bash "$SKILLS/run-company/scripts/init-company.sh" "$DIR" "$NAME" "$IDEA" >/dev/null
# The company GOAL.md starts with the portfolio thesis so every company stays coherent with it.
if ! grep -q '^Portfolio thesis:' "$DIR/GOAL.md"; then
  { echo "# Goal for $NAME"; echo; echo "Portfolio thesis: $THESIS"; tail -n +2 "$DIR/GOAL.md"; } > "$DIR/GOAL.md.new" && mv "$DIR/GOAL.md.new" "$DIR/GOAL.md"
fi
# Inherit the portfolio standing approvals unless the company overrides them.
grep -q '^Inherits: ../../OWNER.md' "$DIR/OWNER.md" || sed -i.bak '1a\
Inherits: ../../OWNER.md (portfolio caps apply unless a line below overrides one)
' "$DIR/OWNER.md" && rm -f "$DIR/OWNER.md.bak"

N=$(( $(grep -cE '^\| *P[0-9]+ *\|' PORTFOLIO.md || true) + 1 ))
ROW="| P$N | $NAME | $DIR | idea | | \$0 | | write GOAL.md numbers, landing page for validation | |"
# Insert the row after the last table line of the "## Companies" section.
awk -v row="$ROW" '
  { lines[NR] = $0 }
  /^## Companies/ { insec = 1 }
  insec && /^## / && !/^## Companies/ { insec = 0 }
  insec && /^\|/ { last = NR }
  END { for (i = 1; i <= NR; i++) { print lines[i]; if (i == last) print row } }
' PORTFOLIO.md > PORTFOLIO.md.new && mv PORTFOLIO.md.new PORTFOLIO.md
echo "- $TODAY - added P$N $NAME ($DIR)" >> PORTFOLIO.md
echo "P$N $NAME -> $DIR"
