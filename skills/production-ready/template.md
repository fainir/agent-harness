# <Product> - Readiness

Definition of done: every row below is `verified`, `cut`, `owner` or `waiting`, and every gate passes.
Statuses: todo | building (who) | verified | owner | waiting | cut (reason)

## Scope

| Surface | Production URL / store / channel | Run | Test | Deploy |
|---|---|---|---|---|
| Web | https://... | `npm run dev` | `npm test` | `railway up` |

## Flows

| ID | Flow (user words) | Surfaces | Status | Evidence | Verified on |
|---|---|---|---|---|---|
| F1 | New user signs up and lands on a useful first screen | web, mobile | todo | | |
| F2 | User logs in, logs out, resets password | web | todo | | |
| F3 | <core job> | | todo | | |
| F4 | Empty, loading and error states of <core screen> | web | todo | | |
| F5 | Pays, gets receipt, refund works | web | todo | | |
| F6 | Deletes account and data | web | todo | | |

## Gates

| Gate | Status | Evidence |
|---|---|---|
| Security: authz on every endpoint, no secrets in repo/logs, rate limits | todo | |
| Data: migrations, backup + one tested restore, delete/export | todo | |
| Reliability: health check, alerts, logs, webhook idempotency | todo | |
| Performance: mobile load, Lighthouse perf and a11y at least 90 | todo | |
| UX/UI: every screen at 375px and desktop, states, contrast, keyboard | todo | |
| Legal/store: privacy, terms, listings and data-safety forms accurate | todo | |
| Ops: CI green, one-command deploy, rollback, env vars documented | todo | |

## Owner actions

1. (none yet) - format: exact place, exact action, what it unblocks.

## Waiting on third parties

| What | Since | Next check | Notes |
|---|---|---|---|

## Log (last 10)

- YYYY-MM-DD - created ledger
