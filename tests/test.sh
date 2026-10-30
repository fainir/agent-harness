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

# 4. harness-notice.py: running chats of both tools hear which rules and skills changed after they started
mkdir -p "$T/sk/ship" "$T/sk/old"; printf '# old\n' > "$T/sk/old/SKILL.md"; touch -t 202001010000 "$T/sk/old/SKILL.md"
printf '{}\n' > "$T/transcript.jsonl"; sleep 1; printf '# rules\n' > "$T/RULES.md"; printf '# ship\n' > "$T/sk/ship/SKILL.md"
hn() { HARNESS_RULES_CLAUDE="$T/RULES.md" HARNESS_RULES_CODEX="$T/CODEX.md" HARNESS_SKILLS_DIR="$T/sk" TMPDIR="$T" "$@"; }
rr() { printf '{"transcript_path":"%s/transcript.jsonl"}' "$T" | hn bash "$HERE/hooks/rules-reload.sh"; }
if { stat -c %W "$T/transcript.jsonl" 2>/dev/null || stat -f %B "$T/transcript.jsonl" 2>/dev/null; } | grep -qE "^[1-9][0-9]*$"; then
  check "harness notice: a running chat hears once that its rules and a skill changed" "rr > '$T/hn1'; grep -q hookSpecificOutput '$T/hn1' && grep -q 'RULES.md' '$T/hn1' && grep -q 'the skill ship (' '$T/hn1'"
  check "harness notice: silent the second time" "[ -z \"\$(rr)\" ]"
else ok "harness notice: skipped (no file birth time on this filesystem)"; fi
printf '# codex rules\n' > "$T/CODEX.md"
check "harness notice: a running Codex chat hears it through the prompt hook" "printf '{\"prompt\":\"go on\",\"session_id\":\"cx1\"}' | HARNESS_TOOL=codex HARNESS_SESSION_START=1000 hn bash '$HERE/hooks/reply-budget.sh' > '$T/hn2'; grep -q 'Reply budget' '$T/hn2' && grep -q 'CODEX.md' '$T/hn2' && ! grep -q 'RULES.md' '$T/hn2'"

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
check "note.sh takes a single line too (the rules ask for one note.sh line)" "LEARNINGS_DIR='$L' bash '$HERE/skills/learn/scripts/note.sh' 'zsh did not split an unquoted variable' | grep -q noted && grep -q '| tool | zsh did not split an unquoted variable | zsh did not split' '$L/inbox.md'"
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
# 6d. init-product.sh seeds the project's QA how-to, so qa-user agents start from it instead of a long brief
IP="$T/initp"; bash "$HERE/skills/ship/scripts/init-product.sh" "$IP/new" "Demo" >/dev/null 2>&1
mkdir -p "$IP/old/qa" && echo "our own notes" > "$IP/old/qa/README.md" && bash "$HERE/skills/ship/scripts/init-product.sh" "$IP/old" "Old" >/dev/null 2>&1
check "init-product: qa/README.md carries a 'How to QA this project' section, and an existing README is kept" "grep -q '^## How to QA this project' '$IP/new/qa/README.md' && [ \"\$(cat '$IP/old/qa/README.md')\" = 'our own notes' ]"
# 6c. a linked worktree's .git points at the main repo: its copies need their own repository, or removing remotes and committing hit the real one
PW="$T/probewt"; mkdir -p "$PW/bin"
(cd "$PW" && git init -q main && cd main && git remote add origin https://example.com/y.git && echo hi > README.md && git add -A && git -c user.email=t@t -c user.name=t commit -qm init && git worktree add -q --detach "$PW/wt")
printf '#!/bin/sh\necho touched > out.txt\ngit add -A >/dev/null 2>&1; git -c user.email=t@t -c user.name=t commit -qm probe >/dev/null 2>&1\nprintf "{\\"result\\":\\"remotes=%%s\\"}\\n" "$(git remote | wc -l | tr -d " ")"\n' > "$PW/bin/claude"; chmod +x "$PW/bin/claude"
WTHEAD=$(git -C "$PW/wt" rev-parse HEAD)
PATH="$PW/bin:$PATH" LEARNINGS_DIR="$PW/l" PROBE_TIMEOUT=60 bash "$HERE/skills/learn/scripts/probe.sh" "$PW/wt" "do it" "$P/cand.md" >/dev/null 2>&1
PDW=$(ls -d "$PW"/l/probes/* 2>/dev/null | head -1)
check "probe: a worktree task keeps the main repo's remote and HEAD, and its copies are offline" "[ \"\$(git -C '$PW/main' remote)\" = origin ] && [ \"\$(git -C '$PW/wt' rev-parse HEAD)\" = '$WTHEAD' ] && grep -q 'remotes=0' '$PDW/A/final.txt' && grep -q 'remotes=0' '$PDW/B/final.txt'"
check "size: every skill is named in the rules block" "HOME='$T/nohome' SKILLS_DIR='$HERE/skills' HARNESS_RULES_FILE='$HERE/rules/harness.md' bash '$HERE/skills/learn/scripts/size.sh' >/dev/null"
SZ="$T/sz"; mkdir -p "$SZ/home/.codex" "$SZ/skills"; { printf '<!-- other:start -->\n'; seq 1 20; printf '<!-- other:end -->\n'; seq 1 70; } > "$SZ/home/.codex/AGENTS.md"
check "size: lines in another tool's marker block are reported, not budgeted" "HOME='$SZ/home' SKILLS_DIR='$SZ/skills' bash '$HERE/skills/learn/scripts/size.sh' | grep -q '^ok .* 70/80.*(+22 managed)'"
seq 1 90 >> "$SZ/home/.codex/AGENTS.md"
check "size: the harness's own lines still fail the budget" "! HOME='$SZ/home' SKILLS_DIR='$SZ/skills' bash '$HERE/skills/learn/scripts/size.sh' >/dev/null"
printf '## rules\n' > "$T/norules.md"
check "size: a skill missing from the rules block fails the budget" "! HOME='$T/nohome' SKILLS_DIR='$HERE/skills' HARNESS_RULES_FILE='$T/norules.md' bash '$HERE/skills/learn/scripts/size.sh' >/dev/null"

# 6b1. zsh-guard.sh: blocks the zsh traps, never a quoted string or a heredoc body
zg() { python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}))' "$1" | SHELL=/bin/zsh bash "$HERE/hooks/zsh-guard.sh" >/dev/null 2>&1; echo $?; }
check "zsh-guard: blocks a loop variable named path" "[ \"\$(zg 'for path in a b; do echo x; done')\" = 2 ]"
check "zsh-guard: blocks set -- \$var and for x in \$list" "[ \"\$(zg 'set -- \$s')\" = 2 ] && [ \"\$(zg 'for x in \$L; do :; done')\" = 2 ]"
check "zsh-guard: blocks an unquoted URL with ? and an unquoted --include glob" "[ \"\$(zg 'curl -s https://x.io/a?b=1')\" = 2 ] && [ \"\$(zg 'grep -r --include=*.js x .')\" = 2 ]"
check "zsh-guard: blocks a word starting with = (echo ======, [ a == b ])" "[ \"\$(zg 'echo ======')\" = 2 ] && [ \"\$(zg '[ \"\$a\" == b ] && echo y')\" = 2 ]"
check "zsh-guard: allows = when quoted, in assignments and options, and == inside [[ ]]" "[ \"\$(zg \"echo '======'\")\" = 0 ] && [ \"\$(zg 'a=b; sort -t= -k2 f; git log --format=%h')\" = 0 ] && [ \"\$(zg '[[ \$a == b ]] && echo y')\" = 0 ]"
check "zsh-guard: allows quoted URLs, messages and heredoc bodies" "[ \"\$(zg \"curl -s 'https://x.io/a?b=1'\")\" = 0 ] && [ \"\$(zg 'git commit -m \"for path in x\"')\" = 0 ] && [ \"\$(zg \"python3 - <<'E'
for path in ps: pass
E\")\" = 0 ]"
check "zsh-guard: does nothing under bash" "python3 -c 'import json; print(json.dumps({\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"for path in a; do :; done\"}}))' | SHELL=/bin/bash bash '$HERE/hooks/zsh-guard.sh'"

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

# 6b. workspace.py builds a project's view from its own files
WS="$T/ws"; mkdir -p "$WS/research"
printf '# Acme - Company ledger\n\nGoal: sell widgets\nStage: building\n\n## Numbers\n\n| KPI | Source | Now | Target | By | Updated |\n|---|---|---|---|---|---|\n| Paid orders | store | 0 | 10 | 2026-12-31 | 2026-10-30 |\n\n## Tracks\n\n| ID | Track | Action (plain words) | Serves | Owner | Status | Due | Evidence |\n|---|---|---|---|---|---|---|---|\n| P1 | product | Ship the store | Paid orders | me | verified | 2026-10-29 | url |\n| G1 | growth | First </script> post | Pageviews | me | todo | 2026-11-01 | |\n\n## Owner actions\n\n1. Stripe -> create account -> unblocks checkout\n\n## Decisions (last 10)\n\n- 2026-10-30 - Price at $29.\n' > "$WS/COMPANY.md"
printf '# Goal for Acme\n\nSell widgets to makers.\n' > "$WS/GOAL.md"
printf '# Acme agent notes\n\n## Working here\n\n- Run tests with npm test.\n' > "$WS/AGENTS.md"
printf '# Market research\n\nMakers buy online.\n' > "$WS/research/market.md"
(cd "$WS" && git init -q && git add -A && git -c user.email=t@t -c user.name=t commit -qm init)
wsgen() { LEARNINGS_DIR="$T/learn-ws" WORKSPACES_DIR="$T/wsreg" python3 -I "$HERE/skills/workspace/scripts/workspace.py" "$@"; }
wsgen "$WS" >/dev/null 2>&1
cat > "$T/ws-check.py" <<'PYCHECK'
import json, sys
d = json.load(open(sys.argv[1] + '/.workspace/data.json'))
ok = (len(d['rows']) == 2 and d['rows'][1]['status'] == 'todo' and d['kpis'][0]['now'] == '0' and d['lessons'][0]['text'].startswith('Run tests')
      and any(x['path'] == 'research/market.md' for x in d['docs']) and d['owner_actions'][0]['done'] is False and d['project']['name'] == 'Acme'
      and d['decisions'][0]['date'] == '2026-10-30' and any(f['path'] == 'GOAL.md' for f in d['files']) and len(d['commits']) == 1)
sys.exit(0 if ok else 1)
PYCHECK
check "workspace: tasks, numbers, docs, lessons, decisions, files and commits read from the files" "python3 -I '$T/ws-check.py' '$WS'"
check "workspace: page named for the project, closing tags in the data escaped" "grep -q '<title>Acme Workspace</title>' '$WS/.workspace/artifact.html' && ! grep -q 'First </script>' '$WS/.workspace/artifact.html'"
check "workspace: .workspace/ kept out of git without touching .gitignore" "git -C '$WS' check-ignore -q .workspace/index.html && [ ! -e '$WS/.gitignore' ]"
WP="$T/wsplan"; mkdir -p "$WP/.claude"
printf '# Gizmo - Master Plan\n\n## Vision\n\nMake gizmos people love.\n\n## Phase 1\n\n- [x] M1 Scaffold - DoD: builds clean\n- [~] Wire the API\n- [ ] Launch page\n- [!] Domain purchase\n- [-] Old idea\n' > "$WP/.claude/plan.md"
printf '# Gizmo\n\nKey sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123 and the service password hunter2hunter2.\n' > "$WP/README.md"
printf 'SERVICE_PASSWORD=hunter2hunter2\n' > "$WP/.env.local"
wsgen "$WP" >/dev/null 2>&1
cat > "$T/ws-plan.py" <<'PYCHECK'
import json, sys
d = json.load(open(sys.argv[1] + '/.workspace/data.json')); r = d['rows']
sys.exit(0 if [x['status'] for x in r] == ['verified', 'building', 'todo', 'owner', 'cut'] and r[0]['id'] == 'M1' and r[0]['dod'] == 'builds clean'
         and d['project']['name'] == 'Gizmo' and d['project']['goal'].startswith('Make gizmos') else 1)
PYCHECK
check "workspace: tasks, name and goal read from .claude/plan.md" "python3 -I '$T/ws-plan.py' '$WP'"
check "workspace: .env values and key-shaped strings never reach the page" "! grep -q 'hunter2hunter2' '$WP/.workspace/artifact.html' && ! grep -q 'sk-ant-api03' '$WP/.workspace/artifact.html' && grep -q 'redacted' '$WP/.workspace/artifact.html'"
wsgen --url "$WS" https://claude.ai/artifact/test123 && wsgen --hub >/dev/null 2>&1
check "workspace: the hub lists every built project and its published page" "grep -q 'Acme' '$T/wsreg/hub/artifact.html' && grep -q 'Gizmo' '$T/wsreg/hub/artifact.html' && grep -q 'claude.ai/artifact/test123' '$T/wsreg/hub/artifact.html'"
check "workspace: --stale lists a project only after its files change" "[ -z \"\$(wsgen --stale)\" ] && touch -t 203001010000 '$WS/COMPANY.md' && [ \"\$(wsgen --stale)\" = '$WS' ]"

# 7. install, reinstall, uninstall in a throwaway HOME
H="$T/home"; mkdir -p "$H/.claude" "$H/.codex"; printf '# my own rules\n' > "$H/.claude/CLAUDE.md"
printf '{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"my-own-hook.sh"}]}]}}\n' > "$H/.claude/settings.json"
inst() { HOME="$H" bash "$HERE/install.sh" "$@" >/dev/null 2>&1; }
inst; inst
check "install: skills linked for every tool" "[ -L '$H/.agents/skills/ship' ] && [ -L '$H/.claude/skills/learn' ] && [ -L '$H/.codex/skills/run-company' ] && [ -L '$H/.agents/skills/workspace' ]"
check "install: one rules block after two installs" "[ \"\$(grep -c 'agent-harness:start' '$H/.claude/CLAUDE.md')\" = 1 ] && grep -q 'my own rules' '$H/.claude/CLAUDE.md'"
check "install: hooks added once, user hooks kept" "python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1]))[\"hooks\"]; s=json.dumps(d); sys.exit(0 if s.count(\"done-check.py\")==1 and s.count(\"continue-ledger.sh\")==1 and \"my-own-hook.sh\" in s and \"UserPromptSubmit\" in d else 1)' '$H/.claude/settings.json'"
check "install: zsh-guard runs before Bash calls only (matcher Bash), and not for Codex" "python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1]))[\"hooks\"][\"PreToolUse\"]; g=[x for x in d if any(\"zsh-guard.sh\" in c[\"command\"] for c in x[\"hooks\"])]; sys.exit(0 if len(g)==1 and g[0].get(\"matcher\")==\"Bash\" else 1)' '$H/.claude/settings.json' && ! grep -q zsh-guard '$H/.codex/hooks.json'"
check "install: codex hooks.json written" "grep -q -- '--judge codex' '$H/.codex/hooks.json'"
inst --uninstall
check "uninstall: links, block and our hooks removed, user content kept" "[ ! -e '$H/.agents/skills/ship' ] && ! grep -q 'agent-harness:start' '$H/.claude/CLAUDE.md' && grep -q 'my own rules' '$H/.claude/CLAUDE.md' && ! grep -q 'done-check' '$H/.claude/settings.json' && grep -q 'my-own-hook.sh' '$H/.claude/settings.json'"

echo; echo "$pass passed, $fail failed"; [ "$fail" -eq 0 ]
