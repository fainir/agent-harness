#!/usr/bin/env bash
# Stop hook (Claude Code and Codex): a session that runs a big job (registered with run-company/scripts/focus.sh)
# does not stop while its ledger still has buildable rows (todo or building). It is sent back to the next row.
# Loop guard: after one push it may stop again only if the ledgers did not change since that push (no progress),
# so a session that cannot move a row is never trapped. Prints JSON on stdout; never fails the stop on its own error.
set -uo pipefail
payload="$(cat 2>/dev/null || true)"
A="${HARNESS_ACTIVE_DIR:-$HOME/.agents/active}"
[ -d "$A" ] || { echo '{}'; exit 0; }
python3 -I - "$A" "$payload" <<'PYEOF' || echo '{}'
import glob, hashlib, json, os, re, sys
active, raw = sys.argv[1], sys.argv[2]
try:
    p = json.loads(raw or "{}")
except Exception:
    p = {}
sid, cwd = str(p.get("session_id") or ""), os.path.realpath(p.get("cwd") or os.getcwd())
dirs = []
if sid and os.path.isfile(os.path.join(active, sid + ".focus")):
    dirs.append((sid, open(os.path.join(active, sid + ".focus")).read().strip()))
for f in glob.glob(os.path.join(active, "dir-*.focus")):
    d = open(f).read().strip()
    if d and (cwd == d or cwd.startswith(d.rstrip("/") + "/")):
        dirs.append((os.path.basename(f)[:-6], d))
if not dirs:
    print("{}"); sys.exit(0)
ROW = re.compile(r"^\|\s*([A-Z]{1,3}\d+|[A-Z][A-Za-z/ ]*:)")
OPEN = re.compile(r"\|\s*(todo|building|building \(me\))\s*\|")  # rows claimed by another worker, "building (name)", are theirs
key, root = dirs[0]
ledgers = [f for name in ("COMPANY.md", "PORTFOLIO.md", "READINESS.md") for f in [os.path.join(root, name)] if os.path.isfile(f)]
ledgers += sorted(glob.glob(os.path.join(root, "*", "READINESS.md")))
buildable, sig = [], hashlib.sha1()
for f in ledgers:
    text = open(f, encoding="utf-8", errors="ignore").read()
    sig.update(text.encode("utf-8", "ignore"))
    for line in text.splitlines():
        if ROW.match(line) and OPEN.search(line) and not re.search(r"\|\s*(owner|waiting|human|cut|verified)\b", line):
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            buildable.append((os.path.relpath(f, root), cells[0], " - ".join(c for c in cells[1:3] if c)[:140]))
state = os.path.join(active, key + ".state")
last = open(state).read().strip() if os.path.isfile(state) else ""
if not buildable:
    print("{}"); sys.exit(0)
if p.get("stop_hook_active") and last == sig.hexdigest():
    sys.stderr.write("continue-ledger: no ledger change since the last push; letting this stop happen\n")
    print("{}"); sys.exit(0)
open(state, "w").write(sig.hexdigest())
f, rid, what = buildable[0]
print(json.dumps({"decision": "block", "reason": (
    "You are running %s: %d buildable rows remain (next: %s %s in %s). Take it now, verify it with evidence, update the ledger, "
    "commit, and go on to the next one. Stop only when every row is verified, owner, waiting, human or cut, or the owner says stop "
    "(then run run-company/scripts/focus.sh --off)." % (os.path.basename(root), len(buildable), rid, what, f))}))
PYEOF
exit 0
