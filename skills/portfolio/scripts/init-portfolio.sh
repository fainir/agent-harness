#!/usr/bin/env bash
# Scaffold a portfolio root. Never overwrites an existing file.
# Usage: init-portfolio.sh <dir> "<Portfolio name>" ["<thesis line>"]
set -euo pipefail

DIR="${1:?portfolio dir}"; NAME="${2:?portfolio name}"; THESIS="${3:-}"
SKILLS="$(cd "$(dirname "$0")/../.." && pwd)"
mkdir -p "$DIR" && cd "$DIR"
TODAY="$(date +%Y-%m-%d)"

put() { if [ -e "$1" ]; then echo "  keep   $1"; cat >/dev/null; else mkdir -p "$(dirname "$1")"; cat > "$1"; echo "  create $1"; fi; }

if [ ! -e PORTFOLIO.md ]; then
  sed -e "s/<Portfolio>/$NAME/g" -e "s/YYYY-MM-DD - created ledger/$TODAY - created ledger/g" "$SKILLS/portfolio/template.md" > PORTFOLIO.md
  [ -n "$THESIS" ] && sed -i.bak -e "s|^Thesis: .*|Thesis: $THESIS|" PORTFOLIO.md && rm -f PORTFOLIO.md.bak
  echo "  create PORTFOLIO.md"
else echo "  keep   PORTFOLIO.md"; fi

if [ ! -e OWNER.md ]; then
  sed -e "s/<Name>/$NAME (portfolio; every company inherits this)/" "$SKILLS/owner-actions/OWNER.template.md" > OWNER.md
  printf '\n## Portfolio\n- Max active companies: 5\n- Validation cap per idea: $0\n- Cut rule: no gate passed within 3 runs or its cap\n' >> OWNER.md
  echo "  create OWNER.md"
else echo "  keep   OWNER.md"; fi

put portfolio/queue.md <<EOF
# $NAME - idea queue (one per line; new-company.sh turns a line into a folder and a table row)

- <slug>: <one sentence: what, for whom, who pays, why now>
EOF

put AGENTS.md <<EOF
# $NAME - portfolio notes

This folder is a portfolio run by the portfolio skill (~/.agents/skills/portfolio/SKILL.md, shared by Codex and Claude Code).
PORTFOLIO.md is the ledger; OWNER.md the standing approvals every company inherits; companies/<slug>/ hold the companies (run-company and ship skills).
- scripts/tick.sh runs one headless worker per active company. The coordinator owns PORTFOLIO.md only.
- Owner actions are batched: one NEEDS YOU line per run.
EOF

put CLAUDE.md <<EOF
@AGENTS.md
EOF

mkdir -p companies .runtime/ticks
if [ -e .gitignore ]; then grep -q '^\.runtime/ticks' .gitignore || printf '\n.runtime/ticks/\n.runtime/*.lock\n' >> .gitignore
else printf '.runtime/ticks/\n.runtime/*.lock\n.env\n.env.*\n!.env.example\n' > .gitignore; echo "  create .gitignore"; fi
[ -d .git ] || git rev-parse --git-dir >/dev/null 2>&1 || { git init -q && echo "  git init"; }
echo "done: $DIR"
