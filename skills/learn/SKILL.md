---
name: learn
description: Make the harness improve itself from real runs. Captures friction while ship, run-company, portfolio and hire run (one line per failing script, unclear step, hook in the way or improvised step), logs each run's numbers, and in a review groups the notes by root cause and makes ONE small tested change to the shared harness (skill text, script, hook, rule) at a time, kept or reverted on the next runs' numbers. Triggers on "improve the harness", "what did you learn", "learn from this", "why did that go wrong", "make yourself better", "תשתפר", /learn, at the end of every big-job run, and in the run-company weekly review. Shared by Claude Code and Codex.
---

# learn - the harness improves itself

Two halves: capture (every run, seconds) and review (weekly or on request, one change at a time). State lives in `~/.agents/learnings/` (inbox.md, runs.log, applied.md), never in chat history.

## 1. Capture (every big-job run)

- Whenever a step fails, is retried, is worked around, needs a step the skill did not name, or asks the owner for something the agent could have done itself: note it at once, one line:
  `bash ~/.agents/skills/learn/scripts/note.sh <project> <phase> "<what happened>" "<root cause>" "<proposed change>" ["<evidence>"]`
  Phases: spec, build, ux, qa, gates, deploy, report, company, portfolio, hire, tool. The script answers how often that root cause was seen; 2 or more means it is promoted in the next review.
- At the end of the run, one line of numbers:
  `bash ~/.agents/skills/learn/scripts/run-log.sh <project> <claude|codex> <verified> <total> <defects> <owner-actions> <reruns> <minutes> ["<note>"]`
- The report's last line is `Learned: <one line, or none>`. A note is never a chore for the owner and never goes in NEEDS YOU.
- Learnings are about the harness (skills, scripts, hooks, rules, prompts), not about the product. Product defects are READINESS rows.

## 2. Review (weekly in run-company, after a project ships, or on request)

1. `bash ~/.agents/skills/learn/scripts/review.sh` prints the open learnings grouped by root cause, the last runs, the last applied changes and the size budget.
2. Pick the ONE root cause with the most rows, or the one that cost the most (a lost run, an avoidable owner action). Overfitting test: if that project disappeared, would the change still be worth it? No: mark its rows `dropped (one-off)`.
2b. Owner load, every review: `review.sh` also shows owner asks by class (owner-actions.log, written by `owner-log.sh` at every NEEDS YOU) and asks per run from runs.log. When a class recurs, the change is whatever removes it: a standing rule proposed in OWNER.md (one yes from the owner), a sign-in saved once in a credentials tool, a default the agent decides alone, a test or sandbox mode, a prepared template, or a human through the hire skill. Owner asks per run must trend down; it is the second keep-or-revert metric next to rows verified.
3. Choose the cheapest level that enforces the fix, highest leverage first: a hook or script that makes the mistake impossible; a script default or argument; one sentence in the skill step where the mistake happened; a rule line. Never a new file when a line will do; delete or replace text before adding.
4. Edit the live harness (`~/.agents/skills`, `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, `~/.claude/hooks`, `~/.claude/rules-library`), then test it: scripts with `bash -n` plus one real invocation; hooks by piping a sample payload into them and checking the output (add the case to `tests/test.sh` in the harness repo); skill or rule text by re-reading the step as the next run will see it; always `bash ~/.agents/skills/learn/scripts/size.sh` (over budget: simplify or discard).
5. Record it: the inbox rows become `applied (date)`; one row in `applied.md` (cause, change, test, PR, verdict pending). If the harness lives in a git repo (the agent-harness clone), commit the change there on a branch and open a PR; merging it is the owner's click, one NEEDS YOU line.
6. Verdict after the next two runs that touch the step, from runs.log and the inbox: the cause did not recur and the numbers held, keep; the numbers dropped or the harness grew for nothing, revert the change and say why in `applied.md`.

One change per review. Many small kept changes beat one rewrite. A change to the harness never waits for the owner; only the PR merge does.

## 3. Hard lines the loop never touches

Security essentials, the always-ask list in OWNER.md, what counts as the owner's click, hook stop behaviour, and this section. A learning that wants to change one of them becomes an owner action carrying the proposed wording.

## 4. Report (end of a review)

```
Learned: <n> open rows, top cause: <cause> (<k> rows across <projects>)
Owner asks: <n> in the window, <older -> newer per run>, top class <class>; proposed rule: <one line, or none>
Changed: <file or script> -> <one sentence> (test: <what ran>) PR <link or none>
Verdict on the previous change: keep | revert | pending (<runs seen>)
Dropped: <n> one-offs
NEEDS YOU (1 of 1): <PR link> -> merge -> unblocks install.sh parity   (only when a PR is open)
```
