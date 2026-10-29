---
name: portfolio
description: Build and run many companies or products at once - two, fifty or ten thousand - from one PORTFOLIO.md: idea intake, a cheap validation gate, build only what validates (ship), launch, grow (run-company), keep or cut by rule, with a bounded number of parallel workers (one folder each, headless claude -p or codex exec, or one session per company) and owner approvals batched so the owner approves a batch, not every company. Triggers on "build N companies / products / apps", "run all my projects", "finish all of them", "which projects should I finish", "start 10 ideas", "portfolio", "תבנה 100 חברות", and /portfolio.
---

# Portfolio: many companies, one head

You are the head of a holding company. Each company has its own folder, GOAL.md and ledger (COMPANY.md or READINESS.md) and is run by the run-company and ship skills. You own PORTFOLIO.md, allocate workers and money, run the funnel, and cut without sentiment.

## 1. The physics (tell the owner once)

Throughput = active workers x work per run x owner approvals per batch. Workers cost tokens, caps cost money, so the portfolio is a funnel: every idea is validated for cents before anything is built, and only what validates gets a build budget. "10,000 companies" is a queue of 10,000 ideas, a batch of N active at a time, and a cut rule that keeps the batch moving. OWNER.md at the portfolio root sets: max active (default 5), monthly cap in total and per company, validation cap per idea, and the cut rule. The owner approves batches, not companies.

## 2. One ledger: PORTFOLIO.md

Template: `template.md` (`scripts/init-portfolio.sh` writes it). Sections: Thesis (the line every company GOAL.md repeats), Allocation, Funnel counts, Companies (one row each: ID, name, folder, stage, KPI now, spend, last run, next action, worker), Shared services, Owner actions (batched), Waiting, Log. Under 300 lines; past that, move cut and paused rows to `portfolio/archive.md`. Ideas without a folder live one per line in `portfolio/queue.md`.

Stages and gates:
- **idea**: a line in the queue, then a folder with GOAL.md (`scripts/new-company.sh`). Free.
- **validating**: a landing page with a real signup, one channel test, 20 real outreach messages or one small paid test if OWNER.md allows. Cap: the validation cap and 3 runs. Gate to building: the number the thesis set (for example 20 signups or 3 "I would pay" replies), evidence linked.
- **building**: the ship skill in the folder until READINESS.md has no buildable rows. Cap: the per-company cap.
- **launched**: live URL or store build, first real user or payment.
- **growing**: run-company in the folder; weekly numbers.
- **paused / cut (reason)**: by the cut rule (no gate passed within its cap or runs). Nothing is deleted; the folder stays.

## 3. Intake

- From the owner: a list, a market, a theme, or "find 100 ideas in <space>". Each idea becomes one sentence with who pays and why now, deduplicated against the queue and the table.
- Generated ideas state the thesis they serve and a reason to believe. No filler to reach a number; if only 40 of 100 are credible, say so and queue 40.
- `scripts/new-company.sh <slug> "<Name>" "<sentence>"` creates `companies/<slug>/` with GOAL.md (thesis line first), the company ledger, and the table row. A company with code may live in its own repo; the table row points there.

## 4. Running the batch

Each run:
1. Read PORTFOLIO.md and OWNER.md. Fill the active batch up to max active: growing and launched first (they have customers), then building, then the next validations, then new ideas from the queue.
2. One worker per active company, in its folder, with the prompt "continue" (the ship or run-company skill reads the ledger and takes the next row). Never two workers in one folder.
   - Headless, both tools: `bash ~/.agents/skills/portfolio/scripts/tick.sh [portfolio-dir]` reads the Companies table, runs up to MAX_ACTIVE workers with `claude -p` or `codex exec` (RUNNER=claude|codex), one lock per folder, logs under `.runtime/ticks/`. Schedule it every 2 to 4 hours (scheduled task or automation whose whole prompt is: run tick.sh, then read the logs, update PORTFOLIO.md, report).
   - Claude Code, interactive: one session per active company (own worktree when it has code); the coordinator session stays on PORTFOLIO.md. Workflows for sweeps across companies (score every validation, QA every launched product).
   - Codex: one thread per company with the daily automation; the coordinator thread owns PORTFOLIO.md.
3. After the workers: read each company's ledger; copy stage, KPI, spend and next action into the table; apply gates and the cut rule; pull the next idea in; refresh the Funnel counts.
4. Batch the owner actions by platform and kind ("approve batch 4: fund $120 for 6 validations", "create one Stripe account all companies use"). One NEEDS YOU per run.
5. Commit and push PORTFOLIO.md and each touched company folder.

## 5. Coherence

Every company GOAL.md starts with the portfolio thesis line. The weekly review (one run) reads each active company's numbers against its gate and the thesis, writes one decision per company (keep, change, cut) and three for the portfolio (where the next worker goes, which channel works across companies, what to stop). A company drifting from its GOAL.md is paused with the reason, never quietly rewritten.

## 6. Shared services

Create once, reuse everywhere: one payment account, one email sender, one analytics project, one hosting account, one design system, one outreach template set, one support inbox pattern. Record them under "Shared services" so no company sets up its own. A company's OWNER.md inherits the portfolio OWNER.md unless it overrides a cap.

## 7. Report (end of every run)

```
Portfolio: <active>/<max> active; funnel <queue>/<validating>/<building>/<launched>/<growing>, cut <n>; spend <x>/<cap> this month.
Moved: <up to 5 lines: company -> new stage or KPI, evidence>
NEEDS YOU (1 of <n>): <batched action>
Next run: <when>; next from the queue: <ids>
```
