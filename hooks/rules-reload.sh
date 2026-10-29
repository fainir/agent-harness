#!/usr/bin/env bash
# PostToolUse hook (Claude Code): a chat reads ~/.claude/CLAUDE.md only when it starts. When the file
# changed after this chat began, tell the model once per change to re-read it, so running chats pick up
# new rules without a restart. Silent otherwise; never blocks.
set -uo pipefail
payload="$(cat 2>/dev/null || true)"
rules="${HARNESS_RULES_FILE:-$HOME/.claude/CLAUDE.md}"
transcript=$(printf '%s' "$payload" | python3 -I -c '
import json, sys
try:
    print(json.load(sys.stdin).get("transcript_path") or "")
except Exception:
    print("")' 2>/dev/null || true)
[ -f "$rules" ] && [ -n "$transcript" ] && [ -f "$transcript" ] || exit 0
mtime() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0; }
born() { stat -f %B "$1" 2>/dev/null || stat -c %W "$1" 2>/dev/null || echo 0; }  # 0 = birth time unknown
r=$(mtime "$rules"); t=$(born "$transcript")
[ "${t:-0}" != 0 ] || exit 0
case "$r$t" in ''|*[!0-9]*) exit 0 ;; esac
key=$(printf '%s' "$transcript" | cksum | cut -d' ' -f1); seen_file="${TMPDIR:-/tmp}/.harness-reload-$key"
[ "$r" -gt "$t" ] && [ "$(cat "$seen_file" 2>/dev/null)" != "$r" ] || exit 0
echo "$r" > "$seen_file"
printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"Your global rules (%s) changed after this chat started: read the file now and follow the current version."}}\n' "$rules"
exit 0
