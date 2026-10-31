---
name: workspace
description: Give every project a workspace the owner can see in one place, like Notion or Monday but built from the project's own files - an overview with numbers and the one owner action, a task board by status, goals, strategy, bets and decisions, a knowledge reader for every doc, what the project learned, every file and the recent activity, plus live sections the project adds - and one all-projects page that links them. Use at the end of every ship, run-company or portfolio run, when a project starts, and whenever the owner asks "show me the project", "where can I see everything", "all my projects", "dashboard", "workspace", "תראה לי את הפרויקט".
---

# Project workspace

The project's files are its workspace; this skill only renders them. Nothing is kept anywhere else, so Claude Code, Codex and the owner always see the same thing.

## The files (what each project keeps and updates)

| Part | File | Updated |
|---|---|---|
| Goal and strategy | GOAL.md; Goal, Stage, Thesis lines, bets and Decisions in the ledger | when the goal or a bet changes |
| Tasks | rows with ID and Status in COMPANY.md, READINESS.md or PORTFOLIO.md (any folder level), and the checkbox tasks of `.claude/plan.md` | every run |
| Numbers | the ledger's KPI table; live numbers from `scripts/workspace-extra.py` | every run |
| Knowledge | root docs (PRODUCT.md, OWNER.md), `.claude/plan.md` and handoff, `research/`, `docs/`, `knowledge/`, sub-project README, AGENTS.md, READINESS.md | when learned or decided |
| Learning | AGENTS.md `## Working here` (project-note.sh) and the shared learnings for this project | as lessons happen |
| Money | `money/` notes and the ledger's Money section | monthly close |
| Files and activity | git: every tracked file (the folder's files outside git), the last 40 commits, the ledger's Log | every commit |

A new project gets these from ship phase 0 or `init-company.sh`; add a missing part as a file, never as a separate tool.

## Build and publish the view

1. `python3 -I ~/.agents/skills/workspace/scripts/workspace.py <project> [...]` writes `.workspace/index.html` (open it locally), `artifact.html` and `data.json`, keeps `.workspace/` out of git through the clone's own exclude list (no tracked file changes), and records the project in `~/.agents/workspaces/registry.json`. Values from the project's `.env` files and anything shaped like a key, token or private key are redacted before anything is written; publish only a page whose line ends "secret check clean". Views: Overview, Tasks (board or table, filter by ledger, search), Strategy, Knowledge, Learning, Files, Activity, and one tab per live section.
2. Claude Code: publish `.workspace/artifact.html` with the Artifact tool (icon `dashboard`; private to the owner), then record the URL: `workspace.py --url <project> <url>` (a `Workspace: <url>` line in the ledger is read too). A republish is read first without rereading the whole page: save the published page (Artifact read with `path: index.html`), run `workspace.py --diff <saved page> .workspace/artifact.html`, read every line it prints and publish only what you can stand behind. A later session reads that url once (Artifact action read) and publishes with it. Codex and headless runs open `.workspace/index.html`.
3. All projects: `workspace.py --hub` writes `~/.agents/workspaces/hub/artifact.html`, one card per registered project (goal, progress, what needs the owner, last commit) linking to its page, with the owner's open asks from every project at the top. Publish it the same way and record it with `workspace.py --hub --url <url>`; pages built after that link back to it.
4. Refresh at the end of every run, after the ledger update and before the report; the report links the workspace. In bulk (a monitor, the portfolio run): `workspace.py --stale` lists the registered projects whose ledger, plan or commits changed since their last build (projects with live sections every time); rebuild and republish those, then the hub.

## Custom views per project

A project adds live sections with an executable `scripts/workspace-extra.py <repo>` that prints `{"sections": [{"id", "title", "kind", ...}]}`; kinds: `kpis` (`items`: label, value, note), `bars` (`bars`: label, value), `table` (`columns`, `rows`), `markdown` (`md`). Read secrets from `.env.local` and never print them.
