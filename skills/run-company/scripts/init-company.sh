#!/usr/bin/env bash
# Scaffold the company harness files into a folder. Never overwrites an existing file.
# Usage: init-company.sh <company-dir> "<Company name>" ["<one-line idea>"]
set -euo pipefail

DIR="${1:?company dir}"; NAME="${2:?company name}"; IDEA="${3:-}"
SKILLS="$(cd "$(dirname "$0")/../.." && pwd)"
mkdir -p "$DIR" && cd "$DIR"
TODAY="$(date +%Y-%m-%d)"

put() { # put <path> <<EOF ... (only if missing)
  if [ -e "$1" ]; then echo "  keep   $1"; cat >/dev/null; else mkdir -p "$(dirname "$1")"; cat > "$1"; echo "  create $1"; fi
}

if [ ! -e COMPANY.md ]; then
  sed -e "s/<Company>/$NAME/g" -e "s/YYYY-MM-DD - created ledger/$TODAY - created ledger/g" "$SKILLS/run-company/template.md" > COMPANY.md
  echo "  create COMPANY.md"
else echo "  keep   COMPANY.md"; fi

if [ ! -e OWNER.md ]; then
  sed -e "s/<Name>/$NAME/" "$SKILLS/owner-actions/OWNER.template.md" > OWNER.md
  echo "  create OWNER.md"
else echo "  keep   OWNER.md"; fi

put GOAL.md <<EOF
# Goal for $NAME
${IDEA:+
Idea: $IDEA
}
Run $NAME as a business: <what it does, for whom, how it makes money>. Success: <number> <paying customers or revenue> by <date>. A run is done when every row in COMPANY.md is verified, human with a due date, owner, waiting or cut, and the next run is scheduled; then report "Goal condition met" with the remaining owner/waiting rows.

Non-goals: <what we are not doing>
Constraints: <budget, time, providers, what the owner never wants>

Paste the paragraph above into Claude Code (/goal) or as the Codex goal.
EOF

put sales/pipeline.md <<EOF
# $NAME - sales pipeline

| Lead | Source | Stage (new / contacted / replied / demo / won / lost) | Next step | Date | Notes |
|---|---|---|---|---|---|
EOF

put money/ledger.md <<EOF
# $NAME - money

Caps: see OWNER.md. Month started: $TODAY

| Date | Item | Amount | Recurring | Running total this month |
|---|---|---|---|---|
EOF

put hires/README.md <<EOF
One brief per hire: hires/<role>-<slug>.md (hire skill, templates.md). hires/log.md records who, what, cost, quality and whether to hire again.
Never store passwords, personal documents or customer data here.
EOF

put hires/log.md <<EOF
# $NAME - hires log

| Date | Name | Role | Platform | Cost | Quality (1 to 5) | Again | Notes |
|---|---|---|---|---|---|---|---|
EOF

put qa/README.md <<EOF
Evidence for COMPANY.md and READINESS.md rows: qa/<row-id>/<date>.png or notes.md. Keep it small; overwrite superseded files. Never store secrets or real customer data here.
EOF

put .runtime/README.md <<EOF
Small machine state only: one-time operations that must never repeat (sent messages, posted jobs, paid items), one line each in <name>-state.json. History lives in git, not here.
EOF

put AGENTS.md <<EOF
# $NAME - agent notes

This folder is a company run by the run-company skill (~/.agents/skills/run-company/SKILL.md, shared by Codex and Claude Code).
COMPANY.md is the ledger, GOAL.md the goal, OWNER.md the standing approvals. Products live in their own folders with a READINESS.md (ship skill). People are hired through the hire skill.

- Every row serves a KPI or a GOAL.md line. Evidence under qa/. Commit and push after each verified row.
- Owner-only items: one exact NEEDS YOU line per run. Money moves only by the owner's click.
- Daily ops prompt: ~/.agents/skills/run-company/heartbeat.md (scheduled task or automation in this folder).
EOF

put CLAUDE.md <<EOF
@AGENTS.md
EOF

if [ -e .gitignore ]; then
  grep -q '^\.runtime/\*\.lock' .gitignore 2>/dev/null || printf '\n.runtime/*.lock\n.runtime/ticks/\n.runtime/runs/\n.runtime/launchd.log\n.runtime/idle.sig\nqa/**/*.webm\n' >> .gitignore
else
  printf 'node_modules/\n.env\n.env.*\n!.env.example\n.runtime/*.lock\n.runtime/ticks/\n.runtime/runs/\n.runtime/launchd.log\n.runtime/idle.sig\nqa/**/*.webm\n' > .gitignore; echo "  create .gitignore"
fi

[ -d .git ] || git rev-parse --git-dir >/dev/null 2>&1 || { git init -q && echo "  git init"; }
echo "done: $DIR"
