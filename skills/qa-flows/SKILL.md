---
name: qa-flows
description: Test every user flow like a skeptical real user on the real surface - fresh state, happy and unhappy paths, mobile and desktop widths, console and network errors, bots by sending real test messages - saving screenshots and notes as evidence under qa/ and setting each READINESS row to verified or filing a defect row. Use after a flow is built, before claiming anything works, before deploy, and as the final regression pass. Passing unit tests never count as QA.
---

# QA flows

Assume it is broken until you have watched it work. You test as a user, not as the author.

## Per flow row (F<n> in READINESS.md)

1. **Fresh state**: new user / cleared storage / new test account (`qa+<flow>@example.com` style on the product's own sign-up; never a real third-party account).
2. **Drive the real UI** at 375px and desktop (or the simulator, or the real bot channel). Click what a user clicks, type what a user types. No API shortcuts for the verdict.
3. **Unhappy paths**: wrong input, empty input, double submit, back button, refresh mid-flow, slow network, expired session, no permission. Each one either behaves well or becomes a defect row.
4. **Watch the plumbing**: browser console has no errors; network has no 4xx/5xx except intended; no secrets or PII in URLs or logs.
5. **Evidence**: `qa/<F-id>/<yyyy-mm-dd>-<width>.png` (one per key step) and `qa/<F-id>/notes.md` (steps, result, date, build or commit). Link `notes.md` from the row.
6. **Verdict**: row `verified` with the evidence link and the date, or `todo` plus a defect row `| D<n> | <flow>: <what went wrong, user words> | <surface> | todo | qa/<F-id>/... | |`. Fix defects in build order; re-test the flow after the fix, not just the defect.

## Bots and integrations

- WhatsApp / Telegram / Slack / email: send a real message from a test account or sandbox number, read the real reply, screenshot the conversation. A webhook log line is not evidence that the user got a reply.
- Payments: provider test mode with its published test cards; verify receipt email, refund, and the failed-card path.

## Tools

- Claude Code: built-in browser (`mcp__Claude_Browser__*`; `resize_window` preset mobile/desktop; `read_console_messages`, `read_network_requests`), Chrome DevTools MCP, iOS simulator tool, `adb` for Android. For parallel coverage of many flows use `.claude/workflows/production-sweep.js` when workflows are enabled.
- Codex: browser plugin / computer use with the same widths; Playwright if the project has it (`npx playwright test`) as a supplement, not the verdict.
- Keep `qa/` small: overwrite the previous screenshot of the same step; delete scratch recordings.

## Final regression

Before deploy and at the end of the goal: every `verified` flow re-run on the production URL in one pass, newest first. Any failure reopens the row. The pass is one line per flow in `qa/regression-<date>.md`.

## What QA never does

- Never marks a row verified from code reading, unit tests or a previous session's claim.
- Never tests only the happy path.
- Never writes "should work" or "looks fine"; it writes what it did and what it saw.
