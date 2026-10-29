---
name: production-ready
description: Use when asked to make a product production ready, finish it, ship it, launch it, close all gaps, QA every feature, flow and UX/UI, or run a long goal or heartbeat toward launch. Defines done with one READINESS.md ledger, builds and verifies flow by flow with real evidence, parks owner-only and third-party blockers without stalling, and ends with an honest short report. Shared by Claude Code and Codex.
---

# Production ready

Companion skills (same folder, `~/.agents/skills/`): `ship` runs the whole idea-to-production pipeline and is the entry point; `product-spec` writes PRODUCT.md and the flow rows; `ux-ui-review` reviews and fixes screens; `qa-flows` verifies rows as a user; `release-gates` runs the release checklist; `owner-actions` hands the owner one action at a time; `run-company` runs the business around a product (COMPANY.md), `portfolio` runs many companies (PORTFOLIO.md), `hire` brings in humans as rows with a due date. This file is the ledger contract they all share: the same statuses, the same evidence rule, the same owner protocol, and `OWNER.md` standing approvals.

"Production ready" means: every in-scope user flow works end to end on the real surface (deployed site, store build, real bot channel), verified with evidence, the release gates below pass, and everything still open is an owner-only action or a third-party wait written down precisely. Passing unit tests is not production ready. An audit is not progress.

Third-party approvals (App Store, Play, Meta/WhatsApp, Google OAuth, payment providers) and real-world adoption (real users, participants, feedback, revenue) are NEVER preconditions of done. They are `waiting` rows. A product whose flows all work and whose only open rows are waits is production ready and the goal is complete.

## 1. One ledger: READINESS.md

Keep exactly one file at the project root, `READINESS.md`, shared by Claude Code, Codex and the human (parallel tracks on other branches: section 5). Create it from `template.md` in this skill folder if missing. Keep it under ~250 lines; it is a live table, not a diary.

- **Scope**: surfaces (web, iOS, Android, extension, WhatsApp, Slack, Telegram, API...), production URLs, how to run, test and deploy (exact commands).
- **Flows**: one row per user flow, written in user words, including unhappy paths. Build the inventory from the code (routes, screens, commands, webhooks, settings, emails), the README and old plans. Typical rows: sign up, log in, log out, reset password, onboarding, the core job, empty/loading/error states, payments and refunds, notifications, settings, delete account/export data, each bot command, each integration connect/disconnect.
- **Gates**: the release checklist in section 4.
- **Owner actions**: only what the agent truly cannot do. Each one is a single exact action (where, what to click or type) plus what it unblocks.
- **Waiting on third parties**: what, since when, next check date.
- **Log**: the last 10 one-line entries. Older history lives in git.

Statuses: `todo`, `building`, `verified`, `owner`, `waiting`, `cut (reason)`. A row is `verified` only with an evidence link: test name, screenshot path, URL, message ID, CI run.

## 2. The loop

1. Read READINESS.md (create it first if missing; that is step one of any production goal).
2. Pick the highest-value row that is not `verified`, `owner` or `waiting`. Order: core flow, money, sign up and onboarding, data safety, then polish.
3. Build or fix it. Smallest correct change, with tests for the logic.
4. Verify it like a user:
   - run the relevant tests;
   - drive the real UI in a browser at 375px and desktop width (or the simulator, or a real test message to the bot) and look at the screenshot;
   - check the console and network for errors; try the empty, error and slow cases;
   - save evidence under `qa/` (screenshots, logs) and link it in the row.
5. Update the row and the log line, commit, push.
6. Next row. QA always finds new problems; add each one as a row rather than fixing silently or forgetting it.

Do a full audit once at the start to build the inventory and once at the end as a regression pass. In between, verify only what changed. Never re-audit unchanged state.

## 3. Blockers never stop the project

- **Owner-only** (payment, password, 2FA code, identity, legal acceptance, account creation, a physical action): write one precise owner action, mark the row `owner`, and move to the next row in the same turn. Collect all owner actions and ask once, at the end.
- **Third-party wait** (App Store or Play review, Meta/WhatsApp business verification, Google OAuth verification, payment provider approval, real users joining): mark `waiting` with a next check date and move on. Check the same unchanged wait at most once a day. Do not write "still waiting" reports.
- **Technical problems are work, not blockers.** Debug, find a workaround, use a test/sandbox mode, mock the provider for the rest of the flow, or cut the row with a reason.
- **Done** = every row is `verified`, `cut`, `owner` or `waiting`, and every gate passes or is an owner/waiting row. Then stop and report "ready except these owner actions". That is a finished goal, not a blocked one.
- **Under a goal loop** (Claude Code `/goal`, Codex goals, heartbeats): when only owner/waiting rows remain, write exactly "Goal condition met: every buildable row is verified; remaining rows are owner/waiting: <list>" and end. Mark a Codex goal complete, not blocked. Never spend a turn only to say you are still waiting.

## 4. Release gates

- **Security**: authorization checked on every endpoint and object, secrets out of the repo and logs, input validation, rate limits on auth and expensive endpoints, dependency audit clean of criticals.
- **Data**: migrations reversible, backups exist and one restore was tested, user data delete/export works.
- **Reliability**: health check, error tracking or alerts, structured logs, retries/idempotency on webhooks and payments, graceful handling when a provider is down.
- **Performance**: key pages load fast on mobile (Lighthouse performance and accessibility at least 90 for web), no N+1 hot paths, sensible bundle size.
- **UX/UI**: every screen checked at 375px and desktop; loading, empty and error states designed; copy is clear; forms have labels, focus states and keyboard use; contrast passes; nothing overflows.
- **Legal and store**: privacy policy, terms, cookie notice where needed, store listings and data-safety forms match what the app does.
- **Ops**: CI green, deploy is one documented command, rollback path known, env vars documented, domains and TLS valid.

## 5. Parallel work

Split by product or surface, never two writers on the same files. One coordinator owns the root `READINESS.md`, merges, and runs the final regression pass. Tracks that live on their own branch or worktree keep their ledger in `readiness/<track>.md` (same format) and the root file links to it, so merging tracks never conflicts on one file. Workers on the same branch claim rows by setting `building (worker name)` and committing that claim before starting. Coordinate through the ledgers and git, not by messaging other chats or pasting chat IDs into prompts.

## 5b. No proof rituals

Evidence is a test name, a screenshot, a URL or a log line linked from the row. Do not write per-step JSON receipts, hash "freezes", lease files, replay journals or writer scripts in `/tmp` to prove you did something. Keep `qa/` under ~200 MB: overwrite superseded screenshots, delete scratch output. If an old ledger, DEFINITION-OF-DONE or STATE file has grown past ~300 lines, distill its live facts into READINESS.md once and stop appending to it. One-time operations that must never repeat (a paid render, a submitted form, a sent message) go in one small `.runtime/<name>-state.json` list, one line each.

## 6. Monitors, heartbeats and scheduled checks

- The prompt is short (under 20 lines) and stable. It says what to check, what to do on each outcome, and where state lives (READINESS.md "Waiting" or a small state file). Never append run results, hashes or history to the prompt, and do not rewrite the prompt during routine runs; change it only when the human changes the scope, or to pause it.
- A build loop (pick a row, build, verify) runs every 2 to 4 hours at most; a monitor for an outside review runs daily. No 10-minute heartbeats except while a job you started is actively running.
- Prefer running heartbeats in a small dedicated thread rather than the main working chat: a check inside a chat with a huge history costs that whole history on every run.
- Frequency matches how fast the thing changes: store or provider reviews daily; an active deploy or render every 15 to 60 minutes and only while it runs.
- Unchanged: end silently or with one line ("no change"), no question, no new work.
- Changed: do the follow-up work, update READINESS.md, tell the user once.
- When the watched thing is resolved, turn the monitor off.
- Use low reasoning effort for pure checks.

## 7. Communication

- Plain sentences a busy founder reads in 30 seconds. No invented compound jargon, no hash dumps, no "proof" walls.
- End of session report, at most 10 lines / 150 words: what became verified (with evidence links), how many rows remain, owner actions (exact), next row, and a `Learned:` line (learn skill: frictions noted with `note.sh` as they happened, the run's numbers logged with `run-log.sh`). No hashes, IDs or file inventories unless the user needs to click them.
- Never claim "production ready", "deployed" or "works" without evidence from this session or a still-valid evidence link.
