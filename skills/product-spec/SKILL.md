---
name: product-spec
description: Turn an idea or an existing codebase into a concrete product spec - who it is for, the core job, every user flow with happy and unhappy paths, non-goals, success metric, stack and data model - written to PRODUCT.md and as flow rows in READINESS.md. Use at the start of /ship, when a goal says "build X" without a spec, or when flows are unclear. Decides instead of asking; asks at most three questions once.
---

# Product spec

Output: `PRODUCT.md` (under 150 lines) and the `## Flows` table of `READINESS.md`. Write both before building.

## PRODUCT.md sections

1. **One line**: `<product> helps <who> <do the job> without <the pain>.`
2. **Who**: the first user, in one paragraph. If the owner is the first user, say so.
3. **Core job**: the one thing the product must do well. Everything else is secondary.
4. **Flows** (5 to 12): each in user words, with the unhappy path next to it. Examples: "Sign up with email, lands on a useful first screen; wrong password shows a clear error; forgotten password resets by email." Include: first run, the core job, empty/loading/error states, payment if any, settings, data export/delete, sign out, each bot command or integration.
5. **Non-goals**: what v1 will not do. Cutting is a decision, write it down.
6. **Success metric**: one number the owner can check weekly.
7. **Stack and hosting**: what the repo uses, or the owner's default stack if PRODUCT.md or OWNER.md names one, else the simplest thing that ships (for example Next.js + Postgres) for a new idea. Run/test/deploy commands.
8. **Data model**: entities and their key fields, in a short table. Privacy notes (what is personal data, retention).
9. **Decisions**: a dated list of choices you made for the owner (name, pricing, copy, scope). The owner can overturn any of them later.
10. **Open questions** (max 3): only things that change the build and that you cannot decide. Ask them once in the report; proceed with your best guess meanwhile and mark the guess.

## Rules

- Existing project: derive flows from the code (routes, screens, commands, webhooks, emails, settings), README and old plans. Do not invent features the code does not have; do add missing unhappy paths.
- A flow is worth a row only if a user would notice it missing or broken.
- Order rows by value: core job, money, sign up/onboarding, data safety, everything else. That order is the build order.
- Write the READINESS rows now: `| F1 | <flow> | <surfaces> | todo | | |`.
- Keep user-facing copy in the product's language (Hebrew products stay Hebrew; English default otherwise).
