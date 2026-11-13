# <Project> - how we work

How this project gets to its goal (processes skill): the strategy that decides what matters now, the recurring processes that do the work (when, how, which runner), and the lanes that let work run in parallel without collisions. <LEDGER> holds the rows (what); this file holds how and when they get done. Under 150 lines; long steps live in the files the How column names.

## Strategy

- Diagnosis: <the one challenge that matters most now, with the numbers that show it>
- Guiding policy: <the approach that answers it, and what we will not do now>
- Coherent actions: <3 to 5 actions that reinforce each other, each with its ledger row IDs>
- Feasible because: <the caps, accounts, runners and hours this needs, and that they exist; the riskiest assumption and its cheapest test>
- Next objective: <a result reachable with what exists, with a number and a date>
- Review by: <YYYY-MM-DD>

## Processes

| ID | Process | When | Runner | How (where the steps live) | Done when | Last run | Health |
|---|---|---|---|---|---|---|---|
<PROCESS ROWS>

Runners: `loop` = the scheduled headless run (terminal and APIs, no browser, no sign-ins); `task:<id>` = a desktop scheduled task (the owner's Chrome and sign-ins); `automation:<id>` = a Codex automation; `session` = an open chat; `agent` = a sub-agent inside a run; `owner`; `human:<name>`. A step that needs a browser or a sign-in never runs on `loop`. When: `every run`, `hourly`, `every 3h`, `daily 16:30`, `weekdays 09:00`, `weekly sun`, `monthly 1`, or `on <event>` / `before <event>`. Health: new, ok, late, failing.

## Lanes

| Lane | Covers (tracks, processes) | Runner | Owns (files) | WIP | Waits on |
|---|---|---|---|---|---|
<LANE ROWS>

Coordinator: the run or session that owns <LEDGER> and this file. It reads the dispatch plan (`processes.py plan`), starts the lanes that can run at once in parallel (sub-agents inside a run, sessions or worktrees for long lanes, headless workers for many folders), gives each lane only its own files, and merges results through the ledger and git. One writer per file set; a lane with WIP reached finishes before it starts more.

## Changes (last 10)

- <YYYY-MM-DD> - <process ID> - <what changed in its How, When or Runner> - why: <the run or number that showed the problem> - read on <date>: pending
