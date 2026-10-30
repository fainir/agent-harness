#!/usr/bin/env bash
# PostToolUse hook (Claude Code): a chat reads ~/.claude/CLAUDE.md only when it starts and keeps the skills it already
# read. When the rules or a shared skill changed after this chat began, tell the model once per change to re-read them,
# so running chats follow the current harness without a restart (harness-notice.py). Silent otherwise; never blocks.
set -uo pipefail
cat 2>/dev/null | python3 -I "$(dirname "$0")/harness-notice.py" --json PostToolUse 2>/dev/null || true
exit 0
