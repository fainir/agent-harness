---
name: release-gates
description: Run the production release checklist with concrete commands and evidence - security, data safety, reliability, performance, legal and store requirements, operations - and record each gate in READINESS.md as verified, owner or waiting. Use before the first production deploy, before a store submission, and at the end of /ship. Technical gaps are fixed, not reported.
---

# Release gates

Each gate ends as a READINESS `## Gates` row with evidence. A gate you cannot pass because of an owner-only item becomes `owner` with one exact action; a provider review becomes `waiting`.

| Gate | Check (do, then link the evidence) | Pass |
|---|---|---|
| Security: authz | Every route/handler checks the caller's identity and ownership of the object; try another user's id in the URL and the API | 403/404, never data |
| Security: secrets | `git log -p --all -S "sk_live" ...` and a grep for `API_KEY=`, `SECRET=`, tokens, private keys in the repo and in logs; `.env*` ignored; `.env.example` lists every variable | none found |
| Security: input and abuse | Validation on every input; rate limit on auth, send, upload and expensive endpoints; CSRF where cookies are used; file uploads type- and size-checked | each present |
| Security: dependencies | `npm audit --omit=dev` / `pip-audit` / `cargo audit` | no critical or high, or a dated accepted-risk note |
| Data: migrations and backups | Migrations run forward on a copy of prod data; a backup exists, and ONE restore was actually performed into a scratch database | restore log |
| Data: user rights | Delete account removes or anonymises the user's data; export works; privacy policy says what is collected and why | tested |
| Reliability: health and alerts | `/api/health` returns version and dependency status; error tracking or at least structured logs; an alert reaches the owner when the health check fails | curl output, alert test |
| Reliability: webhooks and jobs | Webhooks are idempotent (replay the same event twice); retries with backoff; a provider outage degrades gracefully | replay test |
| Performance | Lighthouse (Chrome DevTools `lighthouse_audit`) on the main screen on mobile: performance and accessibility at least 90; no N+1 on list endpoints; bundle size sane | report saved under `qa/perf/` |
| UX/UI | ux-ui-review done for every screen; no open U-rows above minor | rows |
| Legal and store | Privacy policy, terms, cookie notice where required, contact address; store listing text, screenshots and data-safety form match what the app does | URLs |
| Ops | CI green on main; one documented deploy command; rollback = redeploy previous build, tried once; domain + TLS valid; env vars documented; the owner can run it from README in 10 minutes | README, CI link |
| Cost | Monthly cost estimated (hosting, AI tokens, SMS, email) with a cap or alert set in each provider | numbers in PRODUCT.md |

## Rules

- Fix what you can before writing the row. A failing gate is a defect, not a finding.
- Owner-only (buying a domain, enabling a paid plan, accepting provider terms, store developer account): `owner` row with the exact click path.
- Provider reviews: `waiting` row with next check date; check at most daily.
- Evidence lives under `qa/gates/`; keep only the latest per gate.
