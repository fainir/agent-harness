#!/usr/bin/env bash
# Offline test suite: syntax, every hook on sample payloads, the learn scripts, and a full install,
# reinstall and uninstall cycle in a throwaway HOME. Never calls a model. Usage: bash tests/test.sh
set -u  # no pipefail: `grep -q` closing a pipe early must not fail a check
HERE="$(cd "$(dirname "$0")/.." && pwd)"; pass=0; fail=0
ok() { pass=$((pass + 1)); echo "ok   $1"; }
no() { fail=$((fail + 1)); echo "FAIL $1"; }
check() { if eval "$2"; then ok "$1"; else no "$1"; fi; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

# 1. Syntax
for f in "$HERE"/install.sh "$HERE"/hooks/*.sh "$HERE"/skills/*/scripts/*.sh; do check "bash -n $(basename "$f")" "bash -n '$f'"; done
check "python compiles done-check.py" "python3 -I -m py_compile '$HERE/hooks/done-check.py'"

# 2. reply-budget.sh
rb() { printf '%s' "$1" | bash "$HERE/hooks/reply-budget.sh"; }
check "reply budget: short prompt gets 4 lines" "rb '{\"prompt\":\"is it ready?\"}' | grep -q 'at most 4 lines'"
check "reply budget: 70 words get 10 lines" "rb \"{\\\"prompt\\\":\\\"$(yes w | head -70 | tr '\n' ' ')\\\"}\" | grep -q 'at most 10 lines'"
check "reply budget: broken payload still answers" "rb 'not json' | grep -q 'Reply budget'"

# 3. owner-action-nudge.sh
mkdir -p "$T/co"; printf '# C\n\n## Owner actions\n\n1. Stripe -> create account -> unblocks checkout\n' > "$T/co/COMPANY.md"
nudge() { (cd "$T/co" && printf '%s' "$1" | HOME="$T/home0" bash "$HERE/hooks/owner-action-nudge.sh" 2>&1); }
check "nudge: asks for exactly one owner action" "nudge '{}' | grep -q 'NEEDS YOU (1 of 1)'"
check "nudge: warns when a company has no schedule" "nudge '{}' | grep -q 'no scheduled run'"
check "nudge: silent when already continued" "[ -z \"\$(nudge '{\"stop_hook_active\":true}')\" ]"

# 4. rules-reload.sh
printf '{}\n' > "$T/transcript.jsonl"; sleep 1; printf '# rules\n' > "$T/RULES.md"
rr() { printf '{"transcript_path":"%s/transcript.jsonl"}' "$T" | HARNESS_RULES_FILE="$T/RULES.md" TMPDIR="$T" bash "$HERE/hooks/rules-reload.sh"; }
if { stat -c %W "$T/transcript.jsonl" 2>/dev/null || stat -f %B "$T/transcript.jsonl" 2>/dev/null; } | grep -qE "^[1-9][0-9]*$"; then
  check "rules reload: nudges once when rules changed after the chat began" "rr | grep -q 'changed after this chat started'"
  check "rules reload: silent the second time" "[ -z \"\$(rr)\" ]"
else ok "rules reload: skipped (no file birth time on this filesystem)"; fi

# 5. done-check.py local passes (no judge call)
dc() { (cd "$T" && printf '%s' "$1" | DONE_CHECK_TEST=1 python3 -I "$HERE/hooks/done-check.py" --judge codex); }
check "done check: continued turn passes" "[ \"\$(dc '{\"stop_hook_active\":true}')\" = '{}' ]"
check "done check: NEEDS YOU passes" "[ \"\$(dc '{\"last_assistant_message\":\"Built. NEEDS YOU (1 of 1): Stripe -> sign up -> unblocks checkout\",\"cwd\":\"'$T'\"}')\" = '{}' ]"
check "done check: short answer, nothing changed, passes" "[ \"\$(dc '{\"last_assistant_message\":\"Yes, it is ready.\",\"cwd\":\"'$T'\"}')\" = '{}' ]"
check "done check: recursion guard" "[ \"\$(printf '{}' | DONE_CHECK=1 python3 -I '$HERE/hooks/done-check.py')\" = '{}' ]"

# 5b. continue-ledger.sh: a focused session goes on while rows are open, with a no-progress guard
CL="$T/cl"; mkdir -p "$CL/co"; printf '| ID | Track | Action | Serves | Owner | Status | Due | Evidence |\n|---|---|---|---|---|---|---|---|\n| G4 | growth | Free checklist | x | me | todo | | |\n| A1 | admin | Tax | x | owner | owner | | |\n' > "$CL/co/COMPANY.md"
cl() { printf '%s' "$1" | HARNESS_ACTIVE_DIR="$CL/active" bash "$HERE/hooks/continue-ledger.sh" 2>/dev/null; }
check "continue-ledger: silent for a session that is not running a job" "[ \"\$(cl '{\"session_id\":\"s1\",\"cwd\":\"/tmp\"}')\" = '{}' ]"
CLAUDE_CODE_SESSION_ID=s1 HARNESS_ACTIVE_DIR="$CL/active" bash "$HERE/skills/run-company/scripts/focus.sh" "$CL/co" >/dev/null
check "continue-ledger: a focused session with open rows is sent to the next row" "cl '{\"session_id\":\"s1\",\"cwd\":\"/tmp\"}' | grep -q 'next: G4'"
check "continue-ledger: no progress since the last push lets the session stop" "[ \"\$(cl '{\"session_id\":\"s1\",\"cwd\":\"/tmp\",\"stop_hook_active\":true}')\" = '{}' ]"
sed -i.bak 's/| me | todo |/| me | verified |/' "$CL/co/COMPANY.md"
check "continue-ledger: only owner rows left lets the session stop" "[ \"\$(cl '{\"session_id\":\"s1\",\"cwd\":\"/tmp\"}')\" = '{}' ]"
printf '| P9 | product | art | x | me | building (art agent) | | |\n' >> "$CL/co/COMPANY.md"
check "continue-ledger: rows claimed by another worker are not this session's" "[ \"\$(cl '{\"session_id\":\"s1\",\"cwd\":\"/tmp\"}')\" = '{}' ]"
check "continue-ledger: another session is never pushed" "[ \"\$(cl '{\"session_id\":\"s2\",\"cwd\":\"/tmp\"}')\" = '{}' ]"

# 6. learn scripts
L="$T/learnings"
check "note.sh counts a repeated root cause" "LEARNINGS_DIR='$L' bash '$HERE/skills/learn/scripts/note.sh' p qa 'x' 'init script misses the dev command' 'fix' >/dev/null && LEARNINGS_DIR='$L' bash '$HERE/skills/learn/scripts/note.sh' p2 qa 'y' 'init script misses the dev command' 'fix' | grep -q 'seen 2 times'"
check "owner-log.sh counts asks by class" "LEARNINGS_DIR='$L' bash '$HERE/skills/learn/scripts/owner-log.sh' p sign-in 'sign in' 'save it once' | grep -q '1 of class'"
check "run-log.sh logs a run" "LEARNINGS_DIR='$L' bash '$HERE/skills/learn/scripts/run-log.sh' p claude 5 7 1 1 0 30 | grep -q 'logged run 1'"
check "review.sh groups by root cause" "LEARNINGS_DIR='$L' bash '$HERE/skills/learn/scripts/review.sh' 2>/dev/null | grep -q ' 2  init script misses the dev command'"

# 6b. probe.sh with a fake runner: blind labels, candidate in one run only, offline copies, source untouched
P="$T/probe"; mkdir -p "$P/bin" "$P/task"
(cd "$P/task" && git init -q && git remote add origin https://example.com/x.git && echo hi > README.md && git add -A && git -c user.email=t@t -c user.name=t commit -qm init && mkdir .vercel)
printf '#!/bin/sh\ncand=no; for a in "$@"; do [ "$a" = "--append-system-prompt" ] && cand=yes; done\necho touched > out.txt\nprintf "{\\"result\\":\\"candidate=%%s remotes=%%s\\",\\"num_turns\\":2}\\n" "$cand" "$(git remote | wc -l | tr -d " ")"\n' > "$P/bin/claude"; chmod +x "$P/bin/claude"; echo "Always quote proof." > "$P/cand.md"
PATH="$P/bin:$PATH" LEARNINGS_DIR="$P/l" PROBE_TIMEOUT=60 bash "$HERE/skills/learn/scripts/probe.sh" "$P/task" "do it" "$P/cand.md" >/dev/null 2>&1
PD=$(ls -d "$P"/l/probes/* 2>/dev/null | head -1); ref=$(sed -n 's/^reference=//p' "$PD/key.txt" 2>/dev/null); can=$(sed -n 's/^candidate=//p' "$PD/key.txt" 2>/dev/null)
check "probe: candidate text reaches only the candidate run" "grep -q 'candidate=yes' '$PD/$can/final.txt' && grep -q 'candidate=no' '$PD/$ref/final.txt'"
check "probe: copies are offline and the source is untouched" "grep -q 'remotes=0' '$PD/$can/final.txt' && [ ! -e '$P/task/out.txt' ] && [ \"\$(git -C '$P/task' remote | wc -l | tr -d ' ')\" = 1 ]"
check "probe: records what each run changed" "grep -q 'out.txt' '$PD/$can/changes.txt'"
check "size: every skill is named in the rules block" "HOME='$T/nohome' SKILLS_DIR='$HERE/skills' HARNESS_RULES_FILE='$HERE/rules/harness.md' bash '$HERE/skills/learn/scripts/size.sh' >/dev/null"
SZ="$T/sz"; mkdir -p "$SZ/home/.codex" "$SZ/skills"; { printf '<!-- other:start -->\n'; seq 1 20; printf '<!-- other:end -->\n'; seq 1 70; } > "$SZ/home/.codex/AGENTS.md"
check "size: lines in another tool's marker block are reported, not budgeted" "HOME='$SZ/home' SKILLS_DIR='$SZ/skills' bash '$HERE/skills/learn/scripts/size.sh' | grep -q '^ok .* 70/80.*(+22 managed)'"
seq 1 90 >> "$SZ/home/.codex/AGENTS.md"
check "size: the harness's own lines still fail the budget" "! HOME='$SZ/home' SKILLS_DIR='$SZ/skills' bash '$HERE/skills/learn/scripts/size.sh' >/dev/null"
printf '## rules\n' > "$T/norules.md"
check "size: a skill missing from the rules block fails the budget" "! HOME='$T/nohome' SKILLS_DIR='$HERE/skills' HARNESS_RULES_FILE='$T/norules.md' bash '$HERE/skills/learn/scripts/size.sh' >/dev/null"

# 6b2. run.sh idle gate: no model run when nothing is buildable and nothing changed
IG="$T/ig"; mkdir -p "$IG/co" "$IG/bin"; printf '#!/bin/sh\necho run >> "%s/calls"\n' "$IG" > "$IG/bin/claude"; chmod +x "$IG/bin/claude"
printf '| Product | Folder | Ledger | Stage |\n| Storefront | ./store | x | building |\n| ID | Track | Action | Serves | Owner | Status | Due | Evidence |\n| P1 | product | x | y | me | owner | - | - |\n' > "$IG/co/COMPANY.md"
printf '#!/bin/sh\ncat "%s/state"\n' "$IG" > "$IG/co/signals.sh"; chmod +x "$IG/co/signals.sh"; echo a > "$IG/state"
igrun() { PATH="$IG/bin:$PATH" TIMEOUT=30 BUSY_MIN="${BUSY_MIN:-0}" bash "$HERE/skills/run-company/scripts/run.sh" "$IG/co" >/dev/null 2>&1; }
igrun; igrun
check "run.sh idle gate: the second run with nothing new spends no model run (a products table stage is not a row)" "[ \"\$(wc -l < '$IG/calls' | tr -d ' ')\" = 1 ]"
echo b > "$IG/state"; igrun
check "run.sh idle gate: a change in signals.sh wakes the model" "[ \"\$(wc -l < '$IG/calls' | tr -d ' ')\" = 2 ]"
printf '| P2 | product | y | z | me | todo | - | - |\n' >> "$IG/co/COMPANY.md"; igrun; igrun
check "run.sh idle gate: a buildable row always runs" "[ \"\$(wc -l < '$IG/calls' | tr -d ' ')\" = 4 ]"
sleep 1; echo edit > "$IG/co/notes.md"; BUSY_MIN=30 igrun
check "run.sh: a file changed by a working session keeps the scheduled run out of the folder" "[ \"\$(wc -l < '$IG/calls' | tr -d ' ')\" = 4 ] && grep -q 'busy: notes.md' '$IG/co/.runtime/runs/summary.log'"
BUSY_MIN=30 igrun
check "run.sh: once the session's edit is older than the last check, the scheduled run goes on" "[ \"\$(wc -l < '$IG/calls' | tr -d ' ')\" = 5 ]"

# 6c. per-project learning and cross-project promotion
PN="$T/pn"; mkdir -p "$PN/a/sub" "$PN/b"; printf '# a\n\n## Rules\n\n- keep it small\n' > "$PN/a/AGENTS.md"; (cd "$PN/b" && git init -q)
bash "$HERE/skills/learn/scripts/project-note.sh" "Node 24 rejects node --test tests/; pass a glob" "$PN/a/sub" >/dev/null
check "project-note: writes into the project's Working here, not the shared harness" "grep -A3 '^## Working here' '$PN/a/AGENTS.md' | grep -q 'Node 24 rejects' && grep -q '^- keep it small' '$PN/a/AGENTS.md'"
check "project-note: does not add the same lesson twice" "bash '$HERE/skills/learn/scripts/project-note.sh' 'Node 24 rejects node --test tests/; pass a glob' '$PN/a' | grep -q 'already in' && [ \"\$(grep -c 'Node 24 rejects' '$PN/a/AGENTS.md')\" = 1 ]"
bash "$HERE/skills/learn/scripts/project-note.sh" "Node 24 rejects node --test with a bare directory" "$PN/b" >/dev/null
check "review: a lesson in two projects is a promotion candidate" "PROJECT_ROOTS='$PN' LEARNINGS_DIR='$T/l2' bash '$HERE/skills/learn/scripts/review.sh' 2>/dev/null | grep -q ' 2  Node 24 rejects'"

# 7. install, reinstall, uninstall in a throwaway HOME
H="$T/home"; mkdir -p "$H/.claude" "$H/.codex"; printf '# my own rules\n' > "$H/.claude/CLAUDE.md"
printf '{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"my-own-hook.sh"}]}]}}\n' > "$H/.claude/settings.json"
inst() { HOME="$H" bash "$HERE/install.sh" "$@" >/dev/null 2>&1; }
inst; inst
check "install: skills linked for every tool" "[ -L '$H/.agents/skills/ship' ] && [ -L '$H/.claude/skills/learn' ] && [ -L '$H/.codex/skills/run-company' ]"
check "install: one rules block after two installs" "[ \"\$(grep -c 'agent-harness:start' '$H/.claude/CLAUDE.md')\" = 1 ] && grep -q 'my own rules' '$H/.claude/CLAUDE.md'"
check "install: hooks added once, user hooks kept" "python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1]))[\"hooks\"]; s=json.dumps(d); sys.exit(0 if s.count(\"done-check.py\")==1 and s.count(\"continue-ledger.sh\")==1 and \"my-own-hook.sh\" in s and \"UserPromptSubmit\" in d else 1)' '$H/.claude/settings.json'"
check "install: codex hooks.json written" "grep -q -- '--judge codex' '$H/.codex/hooks.json'"
inst --uninstall
check "uninstall: links, block and our hooks removed, user content kept" "[ ! -e '$H/.agents/skills/ship' ] && ! grep -q 'agent-harness:start' '$H/.claude/CLAUDE.md' && grep -q 'my own rules' '$H/.claude/CLAUDE.md' && ! grep -q 'done-check' '$H/.claude/settings.json' && grep -q 'my-own-hook.sh' '$H/.claude/settings.json'"

echo; echo "$pass passed, $fail failed"; [ "$fail" -eq 0 ]
