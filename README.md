# agent-harness

Skills, rules and hooks that turn a coding agent (Claude Code, Codex, or any agent that reads `AGENTS.md` and Agent Skills) into a product team, a CEO or a portfolio manager, depending on what you ask. You talk in plain words. The agent sizes the job, finishes it, verifies it with real evidence, and asks you only for what it truly cannot do, one exact action at a time.

## What it does

| You type | The agent acts as | It keeps |
|---|---|---|
| a question or a tiny edit | an engineer | nothing extra |
| "fix the login bug" | engineer + QA | the matching row, if a ledger exists |
| "build X", "make it production ready", "finish it" | the whole product team: spec, build, UX review, QA of every flow, release gates, deploy | `READINESS.md` |
| "start a company", "get customers", "make money with it" | the CEO: product, growth, sales, support, money, people | `COMPANY.md` |
| "build 50 products", "finish all my projects" | the portfolio head: a funnel with cheap validation and bounded parallel workers | `PORTFOLIO.md` |
| a step that needs a person | the hiring manager: brief, post, screen, milestones, review | `hires/` |

- **Done means verified.** Every row in a ledger needs evidence: a test, a screenshot at phone and desktop width, a URL check. A Stop hook (`done-check.py`) sends the agent back to work when the user's last request is not verifiably finished.
- **One owner action at a time.** `OWNER.md` holds standing approvals (money caps, accounts, channels, decisions the agent makes alone). Inside them the agent acts; outside them it asks once: `NEEDS YOU (1 of 3): Stripe -> create the account -> unblocks checkout`. Moving money, signing, identity and new third-party accounts are always yours.
- **It keeps running.** `run-company/scripts/schedule.sh` installs a background job (launchd on macOS, cron on Linux) that runs `continue` in a project every few hours, with no chat or app open.
- **It improves itself.** Every friction and every owner ask is logged. A weekly review (`learn` skill) follows the propose, probe, compose loop of [Harness²](https://arxiv.org/abs/2610.14224): it picks one recurring cause, proposes up to two fixes, runs the current harness and the candidate side by side on the same real task in offline copies (`probe.sh`, judged blind), and adopts, merges or keeps the base. Kept changes form an experience library (`applied.md`) that later reviews reuse; a change stays only if verified rows hold and owner asks per run go down.
- **Short answers.** The closing message answers your last message and nothing else; a hook sizes it to what you wrote.

## Install

```bash
git clone https://github.com/fainir/agent-harness ~/agent-harness && ~/agent-harness/install.sh
```

The installer is idempotent and keeps your own content. It links the skills into `~/.agents/skills` (and `~/.claude/skills`, `~/.codex/skills`), adds a marked rules block to `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`, and registers the hooks in `~/.claude/settings.json` and `~/.codex/hooks.json`. In Codex, run `/hooks` once to trust the hooks. New chats pick everything up; running Claude chats are told to re-read the rules after their next tool call. Remove it all with `./install.sh --uninstall`.

Other agents: point them at `~/.agents/skills` and paste `rules/harness.md` into their `AGENTS.md` or system prompt.

## Layout

- `skills/` - `ship`, `production-ready`, `product-spec`, `ux-ui-review`, `qa-flows`, `release-gates`, `owner-actions`, `run-company`, `portfolio`, `hire`, `learn`. Each is a `SKILL.md` plus scripts and templates.
- `rules/harness.md` - the rules block the installer adds: size the job, finish it, the owner protocol, learning, writing.
- `hooks/` - `done-check.py` (Stop, Claude and Codex), `reply-budget.sh` (UserPromptSubmit), `owner-action-nudge.sh` (Stop, one owner action and a missing-schedule warning), `rules-reload.sh` (PostToolUse, Claude).
- `tests/test.sh` - offline tests for every hook, the learn scripts and a full install and uninstall cycle in a throwaway home.

## Limits, honestly

- The agent is only as good as the model and the accounts it can reach. Payments, supplier and platform accounts, domains and anything legal stay owner actions.
- The done check calls a small model at the end of long turns; it fails open, so a broken judge never traps a session.
- Background runs use your CLI logins and spend model usage while they run. Pause one with `schedule.sh --remove <dir>`.

## Contributing

Run `bash tests/test.sh` before a pull request. Keep the harness small: `learn/scripts/size.sh` enforces a size budget, and a change that grows it must pay for itself.

MIT licensed.

---

### More open source by [Nir Feinstein](https://nirfeinste.in)

- [frugal](https://github.com/fainir/frugal) - your agent finds the cheaper honest way before it pays for anything
- [flipback](https://github.com/fainir/flipback) - an automatic `/goal` for every turn: sends Claude Code back when it stops early
- [recall](https://github.com/fainir/recall) - your Claude Code memory in every agent, over MCP
- [most-capable-agent-system-prompt](https://github.com/fainir/most-capable-agent-system-prompt) - the copy-paste prompt for a self-improving agent system
- [All projects](https://nirfeinste.in/#open-source)
