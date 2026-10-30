---
name: workspace
description: Give every project a workspace the owner can see in one place, like Notion or Monday but built from the project's own files - an overview with numbers and the one owner action, a task board by status, goals, strategy, bets and decisions, a knowledge reader for every doc, what the project learned, every file and the recent activity, plus live sections the project adds. Use at the end of every ship, run-company or portfolio run, when a project starts, and whenever the owner asks "show me the project", "where can I see everything", "dashboard", "workspace", "תראה לי את הפרויקט".
---

# Project workspace

The project's files are its workspace; this skill only renders them. Nothing is kept anywhere else, so Claude Code, Codex and the owner always see the same thing.

## The files (what each project keeps and updates)

| Part | File | Updated |
|---|---|---|
| Goal and strategy | GOAL.md; Goal, Stage, Thesis lines, bets and Decisions in the ledger | when the goal or a bet changes |
| Tasks | rows with ID and Status in COMPANY.md, READINESS.md or PORTFOLIO.md (any folder level) | every run |
| Numbers | the ledger's KPI table; live numbers from `scripts/workspace-extra.py` | every run |
| Knowledge | root docs (PRODUCT.md, OWNER.md), `research/`, `docs/`, `knowledge/`, sub-project README, AGENTS.md, READINESS.md | when learned or decided |
| Learning | AGENTS.md `## Working here` (project-note.sh) and the shared learnings for this project | as lessons happen |
| Money | `money/` notes and the ledger's Money section | monthly close |
| Files and activity | git: every tracked file, the last 40 commits, the ledger's Log | every commit |

A new project gets these from ship phase 0 or `init-company.sh`; add a missing part as a file, never as a separate tool.

## Build and publish the view

1. `python3 -I ~/.agents/skills/workspace/scripts/workspace.py <project>` writes `.workspace/index.html` (open it locally), `artifact.html` and `data.json`, and adds `.workspace/` to `.gitignore`. Views: Overview, Tasks (board or table, filter by ledger, search), Strategy, Knowledge, Learning, Files, Activity, and one tab per live section.
2. Claude Code: publish `.workspace/artifact.html` with the Artifact tool (icon `dashboard`; private to the owner). The first publish gives a URL: put it in the ledger as `Workspace: <url>` under the Stage line. Later sessions republish with that `url`; the same session republishes the same file path. Codex and headless runs open or attach `.workspace/index.html`.
3. Refresh at the end of every run, after the ledger update and before the report; the report links the workspace.

## Custom views per project

A project adds live sections with an executable `scripts/workspace-extra.py <repo>` that prints `{"sections": [{"id", "title", "kind", ...}]}`; kinds: `kpis` (`items`: label, value, note), `bars` (`bars`: label, value), `table` (`columns`, `rows`), `markdown` (`md`). Read secrets from `.env.local` and never print them. Before publishing, check the page holds no `.env` value or token (the view embeds the docs).
