---
name: processes
description: Give every project its own way of working and keep improving it - a coherent, feasible strategy (diagnosis, guiding policy, coherent actions tied to ledger rows, a next objective with a number and a date), the recurring processes that do the work (when, how, and which runner - the headless loop, a desktop task with the owner's browser, a Codex automation, a session, a sub-agent, the owner or a human), and lanes that run in parallel with one writer per file set, all in one PROCESSES.md next to the ledger, checked by a script, run every cycle and improved one process at a time. Triggers on "how should this project work", "set up processes", "workflow", "operating model", "strategy", "what runs when", "do more in parallel", "coordinate the work", "תהליכים", "אסטרטגיה", /processes; ship, run-company and portfolio call it at setup, at the start of every run and in the weekly review. Shared by Claude Code and Codex.
---

# processes - how each project works, and how that gets better

The ledger (READINESS.md, COMPANY.md or PORTFOLIO.md) says what to do. `PROCESSES.md` next to it says why this first (Strategy), how and when the recurring work happens and who can run it (Processes), and what runs at the same time without collisions (Lanes), plus what changed in how we work (Changes). One file, under 150 lines; the steps themselves live in the files its How column names (a script, heartbeat.md, a playbook under `processes/`, a scheduled task), so nothing is written twice. Script: `python3 -I ~/.agents/skills/processes/scripts/processes.py <init|plan|due|mark|check> .` (`missing` lists registered projects without one).

## 1. Sized to the project

A product: 4 to 6 processes, 1 to 3 lanes. A company: 6 to 12 processes, 3 to 5 lanes. A portfolio: its own file plus one in every company folder. A question, a fix or a scratch folder needs none. Every process has a trigger and a runner; a process nobody runs is cut.

## 2. Setup (first big-job run, or any project with a ledger and no PROCESSES.md)

1. `processes.py init .` (never overwrites) seeds processes from the ledger type, the folder's schedule and its desktop tasks, and lanes from its folders.
2. Write the Strategy from fresh numbers, the kernel of a good strategy:
   - Diagnosis: the one challenge that matters most now, with the numbers that show it (never the goal restated).
   - Guiding policy: the approach that answers it, and what we will not do now.
   - Coherent actions: 3 to 5 actions that reinforce each other, each naming its ledger rows. A row that works against the policy is cut or re-justified in a Decision line.
   - Feasible because: the OWNER.md caps, accounts, runners and hours it needs exist; the riskiest assumption and its cheapest test. An action that needs what does not exist becomes an owner action or is cut.
   - Next objective (a number and a date reachable with what exists) and Review by.
3. Fit the processes: every recurring thing the project does (orders, inboxes, outreach, releases, QA sweeps, content, money close, reviews) is one row with When, Runner, How and Done when. A step that needs a browser or the owner's sign-ins runs on `task:<id>`, `automation:<id>` or `session`, never on `loop`. When a row names a runner that does not exist, create it (run-company `~/.agents/skills/run-company/scripts/schedule.sh` for the loop, a desktop scheduled task, a Codex automation) or change the row.
4. Lanes: split the open work into lanes that never share files (build, growth, ops are the defaults), WIP 1 each, Waits on names the lane or row it needs.
5. `processes.py check .` until nothing FAILs; each WARN becomes a fix or a row.

## 3. Every run (ship, run-company and portfolio start their loop here)

1. `processes.py plan .` lists every due process with its runner, including processes outside lanes, plus buildable rows and dated results to review. Use each process's configured runner and each result's authorized process or session. Record the decision or next check in its ledger row.
2. The coordinator (the run that owns the ledger and PROCESSES.md) starts those lanes in parallel. Claude Code: one Agent per lane inside the turn, or a session or worktree for a long lane. Codex: one thread or `codex exec` worker per lane. Many folders: the portfolio `tick.sh`. Each lane prompt carries the goal, what its rows serve, its files, the OWNER.md limits and what to hand back (rows updated with evidence).
3. Due processes before new rows. After each one, check its Done when with the verify loop (verify skill), then `processes.py mark . <ID> ok` (or `failing`). A failing process stops new rows on its lane until it is fixed.
4. The headless loop runs only `processes.py due . --runner loop`; what needs a browser waits for its task or session.

## 4. Coordination rules

- One writer per file set. Only the coordinator writes the ledger and PROCESSES.md; lanes report through rows and git, never by pasting state between chats.
- Sync at the end of every unit of work: rows updated, commit, push. The coordinator reads every lane's result before it starts the next wave.
- Effort scales with the job: one lane for a small one, more only for independent work. A late job gets no extra lanes (Brooks's law).
- A lane may deviate from its prompt when that serves the goal better; it logs the deviation.

## 5. Improve (weekly review; strategy monthly or when the objective date passes)

1. `processes.py check .` lists late, failing, unrun and unreadable processes and lanes that share files.
2. Improve ONE process: the one that failed, ran late, needed an improvised step, needed the owner, or produced nothing. Change its How (a script beats a checklist, a checklist beats a sentence), its When or its Runner, and write one Changes line: date, process, change, the evidence, the read date. On the read date keep or revert it.
3. A lesson that changes how a recurring task is done goes into that process's How. Facts (commands, quirks) stay in the project's AGENTS.md `## Working here`. Lessons about the harness itself go to the learn skill.
4. Strategy review: diagnose again from the numbers. Objective hit: set the next one. Missed: say why in a Decision line. Change the guiding policy only on evidence.
5. Report line: `Processes: <n> ran, <n> late or failing; changed <ID>: <one line>; strategy <unchanged | revised: one line>`.

## 6. Why this shape

- Diagnosis, guiding policy, coherent action, proximate objectives: Rumelt, Good Strategy/Bad Strategy (2011).
- A few documented core processes followed by all: Wickman, Traction (EOS). Good intentions don't work, mechanisms do (tool, adoption, inspection): Amazon.
- No standard, no improvement: Toyota standard work and kaizen. Limit work in progress and make policies explicit: Anderson, Kanban.
- An orchestrator with parallel workers, each given an objective, boundaries and an output format, with effort scaled to the task: Anthropic, "How we built our multi-agent research system" (2025).
- What failed here before: a JSON process engine with blocking hooks became ceremony. This is one Markdown file, one script and no hooks.

## 7. Hard lines

PROCESSES.md never widens OWNER.md: a process that pays, sends, posts, signs or deletes stays inside the standing approvals, and owner-only steps stay owner actions. No hook enforces this file; a run that cannot follow it says why in the ledger's Log.
