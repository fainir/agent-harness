---
name: learn
description: Make the harness improve itself from real runs. Captures friction while ship, run-company, portfolio and hire run (one line per failing script, unclear step, hook in the way or improvised step), logs each run's numbers and every owner ask, and in a review picks one recurring cause, proposes candidate fixes, probes them against the current harness on the same real task, and composes ONE small tested change (skill text, script, hook, rule) or keeps the base, kept or reverted on the next runs' numbers. Triggers on "improve the harness", "what did you learn", "learn from this", "why did that go wrong", "make yourself better", "תשתפר", /learn, at the end of every big-job run, and in the run-company weekly review. Shared by Claude Code and Codex.
---

# learn - the harness improves itself

Two levels, like Harness²: each project improves its own harness on every run (its `AGENTS.md` `## Working here`, its own scripts), and the shared harness improves in the weekly review from what recurs across projects. Two halves: capture (every run, seconds) and review (weekly or on request, one change at a time). State lives in `~/.agents/learnings/` (inbox.md, runs.log, owner-actions.log, applied.md, probes/), never in chat history. The review follows Harness² (arXiv 2610.14224): propose, probe, compose, with applied.md as the experience library.

## 1. Capture (every big-job run)

- Whenever a step fails, is retried, is worked around, needs a step the skill did not name, or asks the owner for something the agent could have done itself: note it at once, one line, with evidence (a file, a log line, a transcript moment):
  `bash ~/.agents/skills/learn/scripts/note.sh <project> <phase> "<what happened>" "<root cause>" "<proposed change>" ["<evidence>"]`
  Phases: spec, build, ux, qa, gates, deploy, report, company, portfolio, hire, tool. The script says how often that root cause was seen.
- Every NEEDS YOU, once it is staged: `bash ~/.agents/skills/learn/scripts/owner-log.sh <project> <class> "<what>" "<how to never ask this again>" "<what you staged>"`.
- End of run: `bash ~/.agents/skills/learn/scripts/run-log.sh <project> <claude|codex> <verified> <total> <defects> <owner-actions> <reruns> <minutes> ["<note>"]`, and the report's last line is `Learned: <one line, or none>`.
- Learnings are about the harness, not the product. Product defects are READINESS rows. Facts about one project (its run, test, deploy and QA commands, its quirks, a step that had to be improvised there) go straight into that project's harness: `bash ~/.agents/skills/learn/scripts/project-note.sh "<one line>"` from the project folder; a repeated multi-step procedure becomes a script in the project's `scripts/`.

## 2. Review: propose, probe, compose

1. `bash ~/.agents/skills/learn/scripts/review.sh` prints open learnings grouped by root cause, then the rows whose differently worded causes share most of their words (start clustering by meaning there), owner asks by class, runs per tool, project lessons that recur in two or more projects (promote them into the shared harness and delete the project copies), the last applied changes and the size budget. Read `applied.md` first: reuse what was kept, never re-propose what was reverted.
2. Pick ONE cause: the most rows, the top owner-ask class, or the one that cost a whole run. Evidence rule: every edit traces to a recorded moment; if you cannot name the moment, the edit is speculation. One sighting is noise unless it cost a run or an owner ask.
3. Scope it. Invariant (how any agent plans, uses tools, manages context, delegates, verifies, asks the owner) goes to the shared harness. Domain (one project's facts and procedures) goes to that project's `AGENTS.md`. Never put project facts in shared skills.
4. Propose up to two candidates, each a concrete diff at the cheapest enforcing level: a hook or script that makes the mistake impossible, then a script default, then one sentence in the step where it happened, then a rule line. Replace or delete text before adding. Keeping the base is always a candidate. For an owner-ask class the candidates are what removes the ask: a standing rule proposed in OWNER.md, a saved sign-in, a default the agent decides alone, a test mode, a template, a hire.
5. Probe text and skill changes on the same real task where the cause appeared: `bash ~/.agents/skills/learn/scripts/probe.sh <task-dir> "<task prompt>" <candidate-file>` runs the current harness and the candidate side by side in throwaway, offline copies and saves both under `probes/` as A and B in random order. Judge A against B before opening `key.txt`: did the candidate remove the targeted failure, leave it, or break something else? Probe evidence informs; it does not prove. Scripts and hooks are probed by their tests instead (`bash -n`, one real invocation, a fixture with the failing payload).
6. Compose: adopt one candidate, merge their supported parts, or keep the base. Each choice cites a concrete observation from the probe or the inbox, never an assumed gain. A change the evidence does not support is a regression: it costs context and buys nothing.
7. Test and size: `bash ~/.agents/skills/learn/scripts/size.sh` (over budget or a skill no rules file names: fix before adding). Make it live: a change counts once every running and future Claude Code and Codex session uses it, so the copies both tools load hold it (`~/.agents/skills/<name>`, the hook scripts, and the rules in both `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`), and new hook behavior goes inside a hook both tools already run (`reply-budget.sh` on every prompt, the Claude PostToolUse hook, the Stop hooks), since a new registration reaches only new sessions; running sessions then hear what changed from `harness-notice.py`. Record: inbox rows become `applied (date)`; one experience row in `applied.md` (when it applies, cause, change, evidence, test, PR, verdict pending). Mirror the change into the harness repo on a branch and open a PR; merging it is the owner's click.
8. Verdict after the next two runs that touch the step: the cause did not recur and verified rows and owner asks held or improved, keep; otherwise revert and write why in `applied.md`.

One change per review. Many small kept changes beat one rewrite. A harness change never waits for the owner; only the PR merge does.

## 3. Hard lines the loop never touches

Security essentials, the always-ask list in OWNER.md, what counts as the owner's click, hook stop behaviour, and this section. The metrics that judge a change (run-log fields, review.sh counts, size.sh budgets, the done-check judge, tests) never change in the same review as the change they judge, and a judge never learns which probe variant is which. A learning that wants to cross these lines becomes an owner action carrying the proposed wording.

## 4. Report (end of a review)

```
Learned: <n> open rows, top cause: <cause> (<k> rows across <projects>)
Owner asks: <n> in the window, <older -> newer per run>, top class <class>; proposed rule: <one line, or none>
Probe: <A vs B in one line: what differed>; composed: <adopted | merged | kept base> because <observation>
Changed: <file or script> -> <one sentence> (test: <what ran>) PR <link or none>
Verdict on the previous change: keep | revert | pending (<runs seen>)
NEEDS YOU (1 of 1): <PR link> -> merge -> unblocks install.sh parity   (only when a PR is open)
```
