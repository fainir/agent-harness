#!/usr/bin/env bash
# Harness size budget (learn skill): simpler wins, so a change that pushes a file over budget is simplified or discarded.
# Usage: size.sh [--all | --source]   Check installed package skills, the full inventory, or the source package.
set -uo pipefail
mode="${1:-}"
case "$mode" in ''|--all|--source) ;; *) printf 'Usage: size.sh [--all | --source]\n' >&2; exit 2 ;; esac
[ "$#" -le 1 ] || { printf 'Usage: size.sh [--all | --source]\n' >&2; exit 2; }
HERE="$(cd "$(dirname "$0")" && pwd)" || exit 2
manifest="$HERE/managed-skills.txt"
managed="$(cat "$manifest")" || exit 2
[ -n "$managed" ] || { printf 'The managed skill inventory is empty.\n' >&2; exit 2; }
custom_dir="${SKILLS_DIR:-}"
extra_rules="${HARNESS_RULES_FILE:-}"
if [ "$mode" = --source ]; then
  custom_dir="${custom_dir:-$HERE/../..}"
  extra_rules="${extra_rules:-$HERE/../../../rules/harness.md}"
  [ -f "$extra_rules" ] || { printf 'Source rule file is unavailable: %s\n' "$extra_rules" >&2; exit 2; }
fi
S="${custom_dir:-$HOME/.agents/skills}"; over=0; dash_lines=0
if [ -n "$custom_dir" ] && [ ! -d "$S" ]; then
  printf 'Skill directory is unavailable: %s\n' "$S" >&2
  exit 2
fi
# Lines inside <!-- name:start --> ... <!-- name:end --> blocks are installed by other tools: reported, not budgeted.
row() { local n m label flag=ok; n=$(wc -l < "$1" | tr -d ' '); label=$(printf '%s' "$1" | sed "s|^$HOME|~|")
  m=$(awk '/<!-- [^ ]+:start -->/{b=1} b{c++} /<!-- [^ ]+:end -->/{b=0} END{print c+0}' "$1"); n=$((n - m)); [ "$m" -gt 0 ] && label="$label (+$m managed)"
  [ "$n" -gt "$2" ] && { flag=OVER; over=1; }; printf '%-5s %4s/%-4s %s\n' "$flag" "$n" "$2" "$label"; }
count_dashes() { LC_ALL=C grep -c -e $'\xe2\x80\x93' -e $'\xe2\x80\x94' "$@" || true; }
claude_rules="$HOME/.claude/CLAUDE.md"; codex_rules="$HOME/.codex/AGENTS.md"
if [ "$mode" = --source ]; then
  claude_rules=''; codex_rules=''
  row "$extra_rules" 80
  dash_lines=$((dash_lines + $(count_dashes "$extra_rules")))
else
  if [ -f "$claude_rules" ]; then
    row "$claude_rules" 80
    dash_lines=$((dash_lines + $(grep -v 'em/en-dashes' "$claude_rules" | count_dashes)))
  fi
  if [ -f "$codex_rules" ]; then
    row "$codex_rules" 80
    dash_lines=$((dash_lines + $(count_dashes "$codex_rules")))
  fi
  for f in "$HOME"/.claude/rules-library/*.md; do [ -f "$f" ] && row "$f" 160; done
fi

audit_skill() {
  local n="$1" f="$S/$1/SKILL.md" rf
  if [ ! -f "$f" ]; then
    over=1; printf '%-5s %4s/%-4s %s\n' OVER 0 1 "missing managed skill $n"
    return
  fi
  # The installer links its own skills. Only links from other packages have their own budget.
  if [ -L "$S/$n" ] && ! grep -Fxq -- "$n" "$manifest"; then
    printf '%-5s %4s/%-4s %s\n' ext "$(wc -l < "$f" | tr -d ' ')" - "$(printf '%s' "$f" | sed "s|^$HOME|~|") (linked)"
  else
    row "$f" 90
  fi
  dash_lines=$((dash_lines + $(count_dashes "$f")))
  for rf in "$claude_rules" "$codex_rules" ${extra_rules:+"$extra_rules"}; do
    [ -f "$rf" ] || continue
    grep -Fq -- "$n" "$rf" || { over=1; printf '%-5s %4s/%-4s %s\n' OVER 0 1 "skill $n not named in $(printf '%s' "$rf" | sed "s|^$HOME|~|")"; }
  done
}

audit_tool() {
  local root="$1" rules="$2" n loaded
  [ -d "$root" ] || return
  if [ ! -f "$rules" ]; then
    over=1; printf '%-5s %4s/%-4s %s\n' OVER 0 1 "missing rule file $rules"
  fi
  for n in $managed; do
    [ -f "$S/$n/SKILL.md" ] || continue
    loaded="$root/skills/$n/SKILL.md"
    if ! cmp -s "$S/$n/SKILL.md" "$loaded"; then
      over=1; printf '%-5s %4s/%-4s %s\n' OVER 0 1 "missing or different managed skill at $loaded"
    fi
  done
}

if [ -z "$custom_dir" ] || [ "$mode" = --source ]; then
  printf 'Checking the Agent Harness package in %s.\n' "$S"
  for n in $managed; do audit_skill "$n"; done
fi
if [ -z "$custom_dir" ]; then
  audit_tool "$HOME/.claude" "$claude_rules"
  audit_tool "$HOME/.codex" "$codex_rules"
fi
if [ "$mode" = --all ] || { [ -n "$custom_dir" ] && [ "$mode" != --source ]; }; then
  printf 'Checking all skills in %s.\n' "$S"
  for f in "$S"/*/SKILL.md; do
    [ -f "$f" ] || continue
    n="$(basename "$(dirname "$f")")"
    if [ -n "$custom_dir" ] || ! grep -Fxq -- "$n" "$manifest"; then audit_skill "$n"; fi
  done
fi
if [ "$dash_lines" -gt 0 ]; then over=1; printf '%-5s %4s/%-4s %s\n' OVER "$dash_lines" 0 'lines with an em or en dash in harness text (use " - ")'; else printf '%-5s %4s/%-4s %s\n' ok 0 0 'em or en dashes in harness text'; fi
[ "$over" -eq 0 ]
