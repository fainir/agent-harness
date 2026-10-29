#!/usr/bin/env bash
# UserPromptSubmit hook: one line of context that sizes the closing message to the user's message.
# The closing message answers the last message and nothing else; details live in files.
# Reads the hook payload on stdin ({"prompt": "..."}); prints one line; never blocks (exit 0).
set -uo pipefail
payload="$(cat 2>/dev/null || true)"
words=$(printf '%s' "$payload" | python3 -I -c '
import json, sys
try:
    p = json.load(sys.stdin).get("prompt", "")
except Exception:
    p = ""
print(len(str(p).split()))' 2>/dev/null || echo 0)
case "$words" in ''|*[!0-9]*) words=0 ;; esac
if [ "$words" -le 15 ]; then lines=4; elif [ "$words" -le 60 ]; then lines=8; else lines=10; fi
echo "Reply budget: the user wrote $words words; close with at most $lines lines that answer this message and nothing else (a question gets 1 to 3 sentences; a task gets the result, its evidence and one NEEDS YOU); details go to files, not the message."
exit 0
