#!/usr/bin/env bash
# Harness size budget (learn skill): simpler wins, so a change that pushes a file over budget is simplified or discarded.
# Usage: size.sh   Prints a table; exit 1 when a file is over budget or harness text contains em or en dashes.
set -uo pipefail
S="${SKILLS_DIR:-$HOME/.agents/skills}"; over=0
row() { local n label; n=$(wc -l < "$1" | tr -d ' '); label=$(printf '%s' "$1" | sed "s|^$HOME|~|"); local flag=ok; [ "$n" -gt "$2" ] && { flag=OVER; over=1; }; printf '%-5s %4s/%-4s %s\n' "$flag" "$n" "$2" "$label"; }
[ -f "$HOME/.claude/CLAUDE.md" ] && row "$HOME/.claude/CLAUDE.md" 80
[ -f "$HOME/.codex/AGENTS.md" ] && row "$HOME/.codex/AGENTS.md" 80
for f in "$S"/*/SKILL.md; do [ -f "$f" ] && row "$f" 90; done
for f in "$HOME"/.claude/rules-library/*.md; do [ -f "$f" ] && row "$f" 160; done
d=$( { cat "$S"/*/SKILL.md "$HOME/.codex/AGENTS.md" 2>/dev/null; grep -v 'em/en-dashes' "$HOME/.claude/CLAUDE.md" 2>/dev/null; } | LC_ALL=C grep -c -e $'\xe2\x80\x93' -e $'\xe2\x80\x94' )
if [ "${d:-0}" -gt 0 ]; then over=1; printf '%-5s %4s/%-4s %s\n' OVER "$d" 0 'lines with an em or en dash in harness text (use " - ")'; else printf '%-5s %4s/%-4s %s\n' ok 0 0 'em or en dashes in harness text'; fi
# Skill trigger rule (Harness2): a skill no always-on rules file names is never opened.
for d in "$S"/*/; do
  n=$(basename "$d"); [ -f "$d/SKILL.md" ] || continue
  for rf in "$HOME/.claude/CLAUDE.md" "$HOME/.codex/AGENTS.md" ${HARNESS_RULES_FILE:+"$HARNESS_RULES_FILE"}; do
    [ -f "$rf" ] || continue
    grep -q -- "$n" "$rf" || { over=1; printf '%-5s %4s/%-4s %s\n' OVER 0 1 "skill $n not named in $(printf '%s' "$rf" | sed "s|^$HOME|~|")"; }
  done
done
[ "$over" -eq 0 ]
