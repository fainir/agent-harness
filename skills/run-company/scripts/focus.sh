#!/usr/bin/env bash
# Tell the harness this session is running a big job, so the continue-ledger Stop hook keeps it working on
# the ledger's next buildable row after any small request, until only owner, waiting, human or cut rows are left.
# Usage: focus.sh <dir>     register the ledger folder (COMPANY.md, PORTFOLIO.md or READINESS.md) for this session
#        focus.sh --off     stop: the owner said stop, or the session moves to other work
#        focus.sh --list    show registrations
# Claude Code sessions are matched by CLAUDE_CODE_SESSION_ID; without it (Codex, scripts) the folder itself is
# registered and any session working inside it is kept going.
set -euo pipefail
A="${HARNESS_ACTIVE_DIR:-$HOME/.agents/active}"; mkdir -p "$A"
key="${CLAUDE_CODE_SESSION_ID:-}"
case "${1:-}" in
  --list) for f in "$A"/*.focus; do [ -f "$f" ] && printf '%s  %s\n' "$(basename "$f" .focus)" "$(cat "$f")"; done; exit 0 ;;
  --off)
    if [ -n "$key" ]; then rm -f "$A/$key.focus" "$A/$key.state"; echo "focus off for this session"
    else d="$(pwd -P)"; for f in "$A"/*.focus; do [ -f "$f" ] && [ "$(cat "$f")" = "$d" ] && rm -f "$f" "${f%.focus}.state"; done; echo "focus off for $d"; fi
    exit 0 ;;
esac
dir="$(cd "${1:?usage: focus.sh <dir> | --off | --list}" && pwd -P)"
[ -f "$dir/COMPANY.md" ] || [ -f "$dir/PORTFOLIO.md" ] || [ -f "$dir/READINESS.md" ] || { echo "no ledger in $dir" >&2; exit 1; }
name="${key:-dir-$(printf '%s' "$dir" | cksum | cut -d' ' -f1)}"
printf '%s\n' "$dir" > "$A/$name.focus"; rm -f "$A/$name.state"
if [ -n "$key" ]; then who="session $key"; else who="any session working there"; fi
echo "focus on $dir for $who; the Stop hook keeps it on the next row until only owner, waiting, human or cut rows remain"
