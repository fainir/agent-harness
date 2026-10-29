#!/usr/bin/env bash
# Probe one harness candidate against the current harness on the same real task (learn skill, section 2, step 5).
# Usage: probe.sh <task-dir> "<task prompt>" <candidate-file>
#   <candidate-file> holds the proposed rule or skill text. The candidate run gets it as extra instructions:
#   appended to the system prompt (claude) or to the copy's AGENTS.md (codex). The reference run gets nothing extra.
# Both runs start from throwaway copies of <task-dir> with git remotes and deploy links removed, a rehearsal preamble
# that forbids outward actions, the same model and the same time budget, in parallel. Results land in
# ~/.agents/learnings/probes/<stamp>-<slug>/{A,B}/ (final.txt, changes.txt, meta.txt) in random order;
# key.txt says which is which. Judge A against B before reading key.txt.
# Env: RUNNER=claude|codex (default claude), PROBE_TIMEOUT=900 (seconds per run), PROBE_MODEL (claude model),
#      PROBE_KEEP=1 keeps the copies, LEARNINGS_DIR.
set -uo pipefail
[ $# -ge 3 ] || { sed -n '3,4p' "$0"; exit 2; }
SRC="$(cd "$1" && pwd)" || exit 2; PROMPT="$2"; CAND="$(cd "$(dirname "$3")" && pwd)/$(basename "$3")"
[ -s "$CAND" ] || { echo "candidate file is empty or missing: $3" >&2; exit 2; }
RUNNER="${RUNNER:-claude}"; TIMEOUT="${PROBE_TIMEOUT:-900}"
DIR="${LEARNINGS_DIR:-$HOME/.agents/learnings}/probes/$(date +%Y%m%d-%H%M%S)-$(basename "$SRC" | tr -c 'A-Za-z0-9\n' '-' | cut -c1-30)"
WORK="$(mktemp -d)"; mkdir -p "$DIR"
if [ "${CLAUDECODE:-}" = 1 ]; then unset ANTHROPIC_API_KEY ANTHROPIC_BASE_URL; fi  # use the CLI login, not this session's token
PREAMBLE="This is a sandboxed rehearsal in a throwaway copy of the project. Work normally on the task inside this folder, but do not push, deploy, publish, send messages or email, post, buy, or call any production API. When a step would do one of those, stop and write the exact command you would run."
if [ $((RANDOM % 2)) -eq 0 ]; then REF=A; CANDL=B; else REF=B; CANDL=A; fi
printf 'reference=%s\ncandidate=%s\ncandidate_file=%s\ntask_dir=%s\nrunner=%s\nprompt=%s\n' "$REF" "$CANDL" "$CAND" "$SRC" "$RUNNER" "$PROMPT" > "$DIR/key.txt"

prepare() {  # $1 = copy dir: offline copy of the task folder
  rsync -a --exclude node_modules --exclude .runtime --exclude .venv --exclude __pycache__ "$SRC/" "$1/"
  if git -C "$1" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    for r in $(git -C "$1" remote); do git -C "$1" remote remove "$r"; done
  fi
  rm -rf "$1/.vercel" "$1/.railway" "$1/.netlify" "$1/.firebaserc"
}

run_one() {  # $1 = label, $2 = with candidate (1) or not (0)
  local label="$1" cand="$2" copy="$WORK/$1" out="$DIR/$1" start rc
  mkdir -p "$out"; prepare "$copy"
  start=$(date +%s)
  (
    cd "$copy" || exit 1
    if [ "$RUNNER" = codex ]; then
      [ "$cand" = 1 ] && { printf '\n\n## Extra harness rules for this run\n\n'; cat "$CAND"; } >> AGENTS.md
      exec codex exec --profile build --dangerously-bypass-approvals-and-sandbox --dangerously-bypass-hook-trust --skip-git-repo-check -C "$copy" "$PREAMBLE

$PROMPT"
    else
      set -- -p "$PREAMBLE

$PROMPT" --permission-mode bypassPermissions --no-session-persistence --output-format json
      [ -n "${PROBE_MODEL:-}" ] && set -- "$@" --model "$PROBE_MODEL"
      [ "$cand" = 1 ] && set -- "$@" --append-system-prompt "$(cat "$CAND")"
      exec claude "$@"
    fi
  ) > "$out/raw.txt" 2> "$out/stderr.txt" < /dev/null &
  local pid=$!
  ( sleep "$TIMEOUT"; kill "$pid" 2>/dev/null && echo "[probe] killed after ${TIMEOUT}s" >> "$out/stderr.txt" ) > /dev/null 2>&1 < /dev/null &
  local dog=$!
  wait "$pid"; rc=$?
  { pkill -P "$dog"; kill "$dog"; wait "$dog"; } 2>/dev/null  # stop the timer and its sleep quietly
  python3 -I - "$out/raw.txt" "$out/final.txt" "$out/meta.txt" "$rc" "$(( $(date +%s) - start ))" <<'PYEOF'
import json, sys
raw, final, meta, rc, secs = sys.argv[1:6]
text = open(raw, encoding="utf-8", errors="ignore").read()
info = {"exit": rc, "seconds": secs}
try:
    d = json.loads(text.strip().splitlines()[-1])
    text = d.get("result", text)
    for k in ("num_turns", "total_cost_usd", "is_error"):
        if k in d: info[k] = d[k]
except Exception:
    pass
open(final, "w").write(text.strip() + "\n")
open(meta, "w").write("".join("%s=%s\n" % kv for kv in info.items()))
PYEOF
  if git -C "$copy" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    { git -C "$copy" status --porcelain; echo "--- commits since the copy:"; git -C "$copy" log --oneline "$(git -C "$SRC" rev-parse HEAD 2>/dev/null)..HEAD" 2>/dev/null; echo "--- diff stat:"; git -C "$copy" diff --stat HEAD 2>/dev/null | tail -n 20; } > "$out/changes.txt"
  else
    (cd "$copy" && find . -type f -newer "$DIR/key.txt" -not -path './.git/*' | head -n 50) > "$out/changes.txt"
  fi
}

run_one "$REF" 0 & p1=$!
run_one "$CANDL" 1 & p2=$!
wait "$p1"; wait "$p2"
[ "${PROBE_KEEP:-0}" = 1 ] && echo "copies kept in $WORK" || rm -rf "$WORK"
for l in A B; do
  printf '\n== %s: %s ==\n' "$l" "$(tr '\n' ' ' < "$DIR/$l/meta.txt")"
  head -c 600 "$DIR/$l/final.txt"; echo
  echo "-- changed: $(grep -cvE '^(---|$)' "$DIR/$l/changes.txt" 2>/dev/null || echo 0) lines in changes.txt"
done
echo; echo "probe saved in $DIR (judge A vs B first, then read key.txt)"
