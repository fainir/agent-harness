#!/usr/bin/env bash
# Scaffold the production-ready harness files into a project. Never overwrites an existing file.
# Usage: init-product.sh <project-dir> "<Product name>" ["<one-line idea>"]
set -euo pipefail

DIR="${1:?project dir}"; NAME="${2:?product name}"; IDEA="${3:-}"
SKILLS="$(cd "$(dirname "$0")/../.." && pwd)"
mkdir -p "$DIR" && cd "$DIR"
TODAY="$(date +%Y-%m-%d)"

put() { # put <path> <<EOF ... (only if missing)
  if [ -e "$1" ]; then echo "  keep   $1"; cat >/dev/null; else mkdir -p "$(dirname "$1")"; cat > "$1"; echo "  create $1"; fi
}

if [ ! -e READINESS.md ]; then
  sed -e "s/<Product>/$NAME/" -e "s/YYYY-MM-DD - created ledger/$TODAY - created ledger/" "$SKILLS/production-ready/template.md" > READINESS.md
  echo "  create READINESS.md"
else echo "  keep   READINESS.md"; fi

if [ -e ../OWNER.md ] || [ -e ../../OWNER.md ]; then echo "  skip   OWNER.md (the company or portfolio folder above has one)"
elif [ ! -e OWNER.md ]; then
  sed -e "s/<Name>/$NAME/" "$SKILLS/owner-actions/OWNER.template.md" > OWNER.md
  echo "  create OWNER.md"
else echo "  keep   OWNER.md"; fi

put PRODUCT.md <<EOF
# $NAME

One line: $NAME helps <who> <do the job> without <the pain>.
${IDEA:+Idea: $IDEA}

## Who
## Core job
## Flows
(see READINESS.md)
## Non-goals
## Success metric
## Stack and hosting
Run: | Test: | Deploy:
## Data model
## Decisions
- $TODAY -
## Open questions
EOF

put GOAL.md <<EOF
# Goal for $NAME

Make $NAME production ready: every flow and gate in READINESS.md is verified on the real surface with evidence, or is an exact owner action or a dated third-party wait. Done when no buildable row remains; then report "Goal condition met" with the remaining owner/waiting rows.

Paste the paragraph above into Claude Code (/goal) or as the Codex goal. Budget: <time, money, providers the owner allowed>.
EOF

put qa/README.md <<EOF
Evidence for READINESS.md rows. Layout: qa/<row-id>/<date>-<width>.png and qa/<row-id>/notes.md;
qa/ux/, qa/gates/, qa/perf/, qa/prod/ for reviews, gates, Lighthouse and production smoke tests.
Keep it small: overwrite superseded screenshots. Never store secrets or real user data here.
EOF

put .runtime/README.md <<EOF
Small machine state only: one-time operations that must never repeat (paid renders, submitted forms,
sent messages), one line each in <name>-state.json. History lives in git, not here.
EOF

put AGENTS.md <<EOF
# $NAME - agent notes

Production work follows the ship and production-ready skills in ~/.agents/skills/ (shared by Codex and
Claude Code). READINESS.md is the definition of done; PRODUCT.md is the spec; GOAL.md is the goal sentence.

- Run / test / deploy: see PRODUCT.md "Stack and hosting".
- Owner-only items: one exact action at a time (owner-actions skill). Third-party reviews are waiting rows.
- Evidence under qa/. Commit and push after each verified flow. Only commit files you changed.
EOF

put CLAUDE.md <<EOF
@AGENTS.md
EOF

mkdir -p .claude/workflows
if [ ! -e .claude/workflows/production-sweep.js ]; then
  cp "$SKILLS/ship/workflows/production-sweep.js" .claude/workflows/production-sweep.js && echo "  create .claude/workflows/production-sweep.js"
else echo "  keep   .claude/workflows/production-sweep.js"; fi

if [ -e .gitignore ]; then
  grep -q '^\.runtime/\*\.lock' .gitignore 2>/dev/null || printf '\n.runtime/*.lock\nqa/**/*.webm\n' >> .gitignore
else
  printf 'node_modules/\n.env\n.env.*\n!.env.example\n.runtime/*.lock\nqa/**/*.webm\n' > .gitignore; echo "  create .gitignore"
fi

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { git init -q && echo "  git init"; }
echo "done: $DIR"
