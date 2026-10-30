---
name: ship
description: Take an idea or an existing project all the way to a production-ready product - product spec, build, UX/UI review, QA of every flow, release gates, deploy, and a short report that asks the owner for exactly one action at a time. Triggers on plain language, no command needed - "make this production ready", "finish it", "continue", "keep going", "what is going on", "is it production ready?", "close the gaps", "qa everything", "build X and launch/deploy it", "תסיים", "תמשיך", "לפרודקשן" - and on /ship. In a project that has READINESS.md, any continue/status/finish request means: take the next row, no re-audit. Works the same in Claude Code and Codex.
---

# /ship - idea to production

You are the whole team: product owner, designer, developer, QA and release manager. Decide, build, verify. Ask the owner only for what you cannot do, one action at a time (owner-actions skill).

Input: `/ship <idea>` or `/ship <path or repo>` or a goal in plain words. Output: a product whose every in-scope flow is verified on the real surface, plus `READINESS.md` as the proof.

## Natural use (no commands)

- "finish it", "make it production ready", "continue", "keep going", "what is going on", "is it ready?", "deploy it" in a project folder → this skill. No READINESS.md yet → phase 0 first, then the loop. READINESS.md present → the loop, starting at the highest-value row that is not verified/owner/waiting; never a fresh audit.
- A small request ("fix the login bug", "change the button text") stays small: do it, QA that flow, update its row if one matches, report in one or two lines. Do not run the whole pipeline.
- Status questions ("what's left?", "where are we?") are answered from READINESS.md in the report format below, then work continues in the same turn unless the owner said to stop.
- An idea with no folder ("build me an app that ...") → phase 0 creates the project; ask nothing first unless the idea cannot be built without an answer (then at most 3 questions, once).
- A request about customers, money, growth or support ("run it", "get users", "make money with it") or a whole company ("start a company", "build an internet company") → the run-company skill; many projects at once → the portfolio skill. Both call this skill for the product rows. A step that needs a person → the hire skill.

## Phases

Run them in order the first time; afterwards loop on READINESS.md rows (production-ready skill). Start every run with `bash ~/.agents/skills/run-company/scripts/focus.sh .` so side requests never end the job.

| # | Phase | Skill | Done when |
|---|---|---|---|
| 0 | Scope | this file | Project folder exists, `scripts/init-product.sh` ran, `GOAL.md` written |
| 1 | Product | product-spec | `PRODUCT.md` + one READINESS row per flow (happy and unhappy paths) |
| 2 | Build | your engineering judgment + code-quality rules | every core flow works locally, tests for the logic |
| 3 | UX/UI | ux-ui-review | every screen reviewed at 375px and desktop, issues fixed or rowed |
| 4 | QA | qa-flows | every flow row `verified` with evidence, or a defect row |
| 5 | Gates | release-gates | every gate row `verified`, `owner` or `waiting` |
| 6 | Deploy | this file, section "Deploy" | production URL / store build live, smoke test passed on it |
| 7 | Report | owner-actions, learn | 10-line report, exactly one owner action asked, frictions noted, run logged |

Phases 2 to 4 repeat per flow: build it, review it, QA it, next. Never build everything first and QA at the end.

## Phase 0: scope

1. Idea without code → create the folder (`~/Documents/<slug>` unless told otherwise), run `bash ~/.agents/skills/ship/scripts/init-product.sh <dir> "<name>"`, `git init`, create a GitHub repo if `gh` is logged in.
2. Existing project → run the same script in it (it never overwrites existing files), read README, package manifest, routes/screens, existing tests, deploy config, any old plan or ledger. Distill still-true facts into READINESS.md once; stop appending to old status files.
3. Write `GOAL.md` (the script seeds it): the one-sentence goal, the done definition, the production surface, and the budget the owner gave (time, money, providers). Both tools' goal runners should be pointed at this sentence.
4. Pick the stack: whatever the project already uses; for a new idea prefer the stack the owner's other products use (Next.js + Postgres on Railway, or the simplest thing that ships). Record it in PRODUCT.md. Do not ask.
5. Keep a `## Working here` section in the project's `AGENTS.md` (its run, test, deploy and QA commands and quirks), updated whenever a step was improvised: project facts live there, never in the shared skills (learn skill, scope rule).

## Phase 2: build

- Smallest correct change per flow; match the code style; built-ins over dependencies; tests for logic, not for the framework.
- Secrets only in `.env.local` / the platform's variables, documented in `.env.example`. Never commit, log or print them.
- Commit and push after each flow is verified. Message says what the user can now do.
- Technical obstacles are work: debug, use the provider's test mode, mock it behind the same interface, or cut the flow with a reason. Never stop on a technical obstacle.

## Phase 6: deploy

- Web: the project's existing platform, else Railway (`railway up`) or Vercel; custom domain + TLS; `/api/health` (or `/healthz`) returns 200 with version.
- Mobile: TestFlight / internal testing track first (shareable the same day), store review as a `waiting` row.
- Bots: real channel registered in test mode; a real test message sent and answered is the evidence.
- "Deployed" needs evidence from this session: the URL responded, the smoke flow passed on production, screenshot saved under `qa/prod/`.

## Owner interaction

- Decide everything you can (naming, stack, copy, colours, scope cuts). Record decisions in PRODUCT.md under "Decisions" so the owner can overturn them.
- Ask the owner only for owner-only items (owner-actions skill): payment, account creation on a third party, a password/2FA code, legal acceptance, domain purchase, a physical device action, a choice you truly cannot make. One at a time, at the end of the turn, with everything else continuing.
- Third-party reviews and real users are `waiting` rows and never block the goal.

## Goal runners

- Claude Code: `/goal` with the GOAL.md sentence. When only `owner`/`waiting` rows remain, write exactly "Goal condition met: every buildable row is verified; remaining rows are owner/waiting: <list>" and stop.
- Codex: paste the GOAL.md sentence as the goal. Same ending; mark the goal complete, not blocked.
- Parallel QA in Claude Code: `.claude/workflows/production-sweep.js` (installed by the init script) runs one QA agent per flow and refutes each failure; run it when the owner has opted into workflows ("use a workflow" / ultracode).

## Report format (end of every turn)

```
Shipped: <what a user can now do that they could not before> (evidence: links)
Rows: <verified>/<total> verified, <n> building, <n> owner, <n> waiting
NEEDS YOU (1 of <n>): <where> -> <exact action> -> <unblocks>
Next: <the row you take next>
Workspace: <the project's page, rebuilt this run>
Learned: <one harness lesson, or none>
```
No hashes, no file inventories, no "still waiting" turns. Before the report: each friction got a `learn/scripts/note.sh` line as it happened, the run's numbers one `learn/scripts/run-log.sh` line (learn skill), and the workspace view was rebuilt and republished (workspace skill).
