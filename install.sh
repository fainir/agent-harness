#!/usr/bin/env bash
# Install the agent harness for Claude Code, Codex and any agent that reads ~/.agents/skills or AGENTS.md.
# Usage: ./install.sh              install or update (idempotent; skills are symlinks, so `git pull` updates them)
#        ./install.sh --uninstall  remove links, rule blocks and hook entries this installer added
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
AGENTS_DIR="$HOME/.agents"; SKILLS="$AGENTS_DIR/skills"; HOOKS="$AGENTS_DIR/hooks"
SKILL_NAMES="ship production-ready product-spec ux-ui-review qa-flows release-gates owner-actions run-company portfolio hire learn workspace"
STAMP="$(date +%Y%m%d-%H%M%S)"
MODE="${1:-install}"

rules_block() {  # write or remove the marked rules block in a rules file
  python3 -I - "$1" "$HERE/rules/harness.md" "$2" <<'EOF'
import os, sys
path, src, mode = sys.argv[1], sys.argv[2], sys.argv[3]
start, end = "<!-- agent-harness:start -->", "<!-- agent-harness:end -->"
text = open(path).read() if os.path.exists(path) else ""
if start in text and end in text:
    a, b = text.index(start), text.index(end) + len(end)
    text = (text[:a].rstrip("\n") + "\n" + text[b:].lstrip("\n")).strip("\n") + "\n"
if mode == "add":
    text = (text.rstrip("\n") + "\n\n" if text.strip() else "") + start + "\n" + open(src).read().rstrip("\n") + "\n" + end + "\n"
os.makedirs(os.path.dirname(path), exist_ok=True)
open(path, "w").write(text)
EOF
}

hooks_json() {  # add or remove our hook entries in a Claude settings.json or a Codex hooks.json
  python3 -I - "$1" "$2" "$3" "$HOOKS" <<'EOF'
import json, os, shutil, sys
path, tool, mode, hooks = sys.argv[1:5]
data = json.load(open(path)) if os.path.exists(path) else {}
if os.path.exists(path):
    shutil.copy(path, path + ".bak-harness")
h = data.setdefault("hooks", {})
for event in list(h):  # drop our previous entries, keep everything else
    for group in h[event]:
        group["hooks"] = [c for c in group.get("hooks", []) if hooks not in c.get("command", "")]
    h[event] = [g for g in h[event] if g.get("hooks")]
    if not h[event]:
        del h[event]
if mode == "add":
    judge = "claude" if tool == "claude" else "codex"
    want = {
        "UserPromptSubmit": ["bash \"%s/reply-budget.sh\"" % hooks],
        "Stop": ["python3 -I \"%s/done-check.py\" --judge %s" % (hooks, judge), "bash \"%s/owner-action-nudge.sh\"" % hooks, "bash \"%s/continue-ledger.sh\"" % hooks],
    }
    if tool == "claude":
        want["PostToolUse"] = ["bash \"%s/rules-reload.sh\"" % hooks]
        want["PreToolUse"] = ["bash \"%s/zsh-guard.sh\"" % hooks]  # Claude Code's Bash tool runs the login shell, zsh on macOS
    for event, cmds in want.items():
        entry = [{"type": "command", "command": c, "timeout": 150 if "done-check" in c else 10} for c in cmds]
        h.setdefault(event, []).append({"matcher": "Bash", "hooks": entry} if event == "PreToolUse" else {"hooks": entry})
if not h:
    data.pop("hooks", None)
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")
EOF
}

link() {  # link $2 -> $1, backing up anything else already there
  if [ -L "$2" ] || [ ! -e "$2" ]; then ln -sfn "$1" "$2"; else mv "$2" "$2.bak-$STAMP"; ln -sfn "$1" "$2"; echo "  backed up $2 -> $2.bak-$STAMP"; fi
}

if [ "$MODE" = "--uninstall" ]; then
  for s in $SKILL_NAMES; do
    for d in "$SKILLS" "$HOME/.claude/skills" "$HOME/.codex/skills"; do
      [ -L "$d/$s" ] && rm "$d/$s"
    done
  done
  [ -L "$HOOKS" ] && rm "$HOOKS"
  [ -f "$HOME/.claude/CLAUDE.md" ] && rules_block "$HOME/.claude/CLAUDE.md" remove
  [ -f "$HOME/.codex/AGENTS.md" ] && rules_block "$HOME/.codex/AGENTS.md" remove
  [ -f "$HOME/.claude/settings.json" ] && hooks_json "$HOME/.claude/settings.json" claude remove
  [ -f "$HOME/.codex/hooks.json" ] && hooks_json "$HOME/.codex/hooks.json" codex remove
  echo "uninstalled (learnings in $AGENTS_DIR/learnings are kept)"
  exit 0
fi

mkdir -p "$SKILLS" "$AGENTS_DIR/learnings"
chmod +x "$HERE"/hooks/*.sh "$HERE"/hooks/*.py "$HERE"/skills/*/scripts/*.sh 2>/dev/null || true
for s in $SKILL_NAMES; do link "$HERE/skills/$s" "$SKILLS/$s"; done
link "$HERE/hooks" "$HOOKS"
echo "skills linked into $SKILLS"
if [ -d "$HOME/.claude" ] || command -v claude >/dev/null 2>&1; then
  mkdir -p "$HOME/.claude/skills"
  for s in $SKILL_NAMES; do link "$SKILLS/$s" "$HOME/.claude/skills/$s"; done
  rules_block "$HOME/.claude/CLAUDE.md" add
  hooks_json "$HOME/.claude/settings.json" claude add
  echo "Claude Code: skills, rules block in ~/.claude/CLAUDE.md, hooks in ~/.claude/settings.json (new chats pick them up)"
fi
if [ -d "$HOME/.codex" ] || command -v codex >/dev/null 2>&1; then
  mkdir -p "$HOME/.codex/skills"
  for s in $SKILL_NAMES; do link "$SKILLS/$s" "$HOME/.codex/skills/$s"; done
  rules_block "$HOME/.codex/AGENTS.md" add
  hooks_json "$HOME/.codex/hooks.json" codex add
  echo "Codex: skills, rules block in ~/.codex/AGENTS.md, hooks in ~/.codex/hooks.json (run /hooks once in Codex to trust them)"
fi
echo "Other agents: point them at $SKILLS and paste rules/harness.md into their AGENTS.md or system prompt."
