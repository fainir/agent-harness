#!/usr/bin/env bash
# Stop hook (advisory, pure bash): when the project keeps a READINESS.md with open owner actions,
# remind the agent to ask for exactly ONE of them in the fixed NEEDS YOU format (owner-actions skill).
# Never blocks. Silent everywhere else.
set -uo pipefail
case "$(cat 2>/dev/null || true)" in *'"stop_hook_active":true'*|*'"stop_hook_active": true'*) exit 0 ;; esac
n=0; first=""
for f in READINESS.md COMPANY.md PORTFOLIO.md; do
  [ -f "$f" ] || continue
  sec=0
  while IFS= read -r line; do
    case "$line" in
      "## Owner actions"*) sec=1; continue ;;
      "## "*) sec=0 ;;
    esac
    if [ "$sec" = "1" ]; then
      case "$line" in
        *"(none yet)"*|*"done "*|*"DONE"*) ;;
        [0-9]*.*|-\ [0-9]*.*) n=$((n + 1)); [ -z "$first" ] && first="$line" ;;
      esac
    fi
  done < "$f"
done
# A company or portfolio ledger needs a scheduled run (run-company skill, scripts/schedule.sh): warn while none exists.
for f in COMPANY.md PORTFOLIO.md; do
  [ -f "$f" ] || continue
  here="$(pwd -P)"; herel="$(pwd)"
  if ! grep -qs -e "$here" -e "$herel" "$HOME"/Library/LaunchAgents/com.harness.*.plist "$HOME"/.claude/scheduled-tasks/*/SKILL.md 2>/dev/null \
     && ! (crontab -l 2>/dev/null | grep -q -e "harness run.sh $here" -e "harness run.sh $herel"); then
    echo "$f here but no scheduled run for $here: run bash ~/.agents/skills/run-company/scripts/schedule.sh . 3 (or a scheduled task / automation with heartbeat.md) before ending the turn." >&2
  fi
  break
done
[ "$n" -gt 0 ] || exit 0
echo "owner actions open: $n. End the turn with exactly one, in this shape: NEEDS YOU (1 of $n): <where> -> <exact action> -> unblocks <rows>. First on the list: ${first:0:160}" >&2
exit 0
