#!/usr/bin/env bash
# Per-project learning (learn skill, level 1): add one lesson to THIS project's own harness, the
# "## Working here" section of its AGENTS.md, so the next run in this project starts with it.
# Usage: project-note.sh "<fact or procedure, one line>" [dir]
#   dir defaults to the current folder; the project root is the nearest folder upward with AGENTS.md or .git.
# Shared lessons (how any agent works) go through note.sh instead; review.sh promotes project lessons that
# show up in two or more projects into the shared harness (level 2).
set -euo pipefail
[ $# -ge 1 ] && [ -n "$1" ] || { sed -n '4,5p' "$0"; exit 2; }
line="$(printf '%s' "$1" | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"
dir="$(cd "${2:-.}" && pwd)"; root="$dir"
while [ "$root" != "/" ] && [ ! -f "$root/AGENTS.md" ] && [ ! -e "$root/.git" ]; do root="$(dirname "$root")"; done
[ "$root" != "/" ] || root="$dir"
f="$root/AGENTS.md"; [ -f "$f" ] || printf '# %s - agent notes\n' "$(basename "$root")" > "$f"
if grep -qiF -- "$line" "$f"; then echo "already in $f"; exit 0; fi
python3 -I - "$f" "- $line ($(date +%F))" <<'PYEOF'
import sys
path, bullet = sys.argv[1], sys.argv[2]
lines = open(path, encoding="utf-8").read().rstrip("\n").split("\n")
try:
    start = next(i for i, l in enumerate(lines) if l.strip() == "## Working here")
except StopIteration:
    lines += ["", "## Working here", ""]
    start = len(lines) - 2
end = next((i for i in range(start + 1, len(lines)) if lines[i].startswith("## ")), len(lines))
insert = end
while insert > start + 1 and not lines[insert - 1].strip():
    insert -= 1
lines.insert(insert, bullet)
open(path, "w", encoding="utf-8").write("\n".join(lines) + "\n")
n = sum(1 for l in lines[start + 1:end + 1] if l.startswith("- "))
print("noted in %s (%d lines in Working here%s)" % (path, n, "; consolidate: merge or delete stale lines" if n > 30 else ""))
PYEOF
