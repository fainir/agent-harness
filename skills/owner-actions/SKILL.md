---
name: owner-actions
description: How to hand the owner exactly one action at a time when the agent truly cannot do a step itself (payment, third-party account, password or 2FA code, legal acceptance, physical device, a decision only they can make) - record it in READINESS.md, keep working on everything else, ask once at the end of the turn in a fixed format, notify if they are away, verify when done, then ask the next. Use whenever you are about to tell the user to do something.
---

# Owner actions: one at a time

The owner should never receive a list of chores. They get one exact action, everything else keeps moving.

## What counts as owner-only

Paying or entering card details; creating or verifying an account on a third-party service; a password, 2FA code or passkey; accepting legal terms; buying a domain; a physical action (plug in a phone, tap a prompt on their device); granting an OS permission; a product decision you genuinely cannot make. Everything else, including "test it yourself", "read the docs", "configure the server", is your job.

Before asking, check saved sign-ins (a credentials or account-access tool, if your setup has one) and OWNER.md "Decisions the agent makes alone" (the owner may already have delegated it). Every ask is a cost: the learn review drives owner asks per run down, so prefer a standing rule, a saved sign-in, a default you decide, a test mode or a template over a one-off ask.

## Standing approvals: OWNER.md

`OWNER.md` at the project, company or portfolio root (template: `OWNER.template.md` in this folder; the init scripts write it) is where the owner pre-approves what you may do without asking: money per month and per item, accounts you may use, where you may post or message as the company, what you may spend on hiring, hard lines. Read it before every paid, public or outbound action. Inside the limits: act, log the spend or the post, move on. Outside them: one owner action. Caps at 0 mean free actions only; "fill OWNER.md" is then the first NEEDS YOU. Some things are never standing: moving money, signing, registering a company or bank account, identity documents, creating a third-party account, deleting customer data, statements in the owner's own name. The owner edits the file to widen or narrow it; you never edit the caps.

## Protocol

1. **Record** every owner-only item as a numbered line under `## Owner actions` in READINESS.md: `N. <where> -> <exact action> -> unblocks <rows>`. Mark the dependent rows `owner`.
2. **Keep going** in the same turn on every row that does not depend on it.
3. **Stage it, then ask once, at the end of the turn.** First do every step around the owner's click yourself: open the exact page in the owner's own browser, fill every field that is not a secret, payment detail or identity document, and start a watcher that notices when it is done. Never ask whether to open, prepare, deploy or continue something free and reversible; that question is itself an unnecessary ask. Then ask for the single most unblocking item, naming the tab already open, in this exact shape:
   ```
   NEEDS YOU (1 of <n>): <where, with URL or app name> -> <exact thing to click, type or send> -> unblocks <what>
   ```
   Never two. The rest stay in READINESS.md. Log the ask: `bash ~/.agents/skills/learn/scripts/owner-log.sh <project> <class> "<what>" "<how to never ask this again>" "<what you staged>"` (class: sign-in, money, new-account, signature, identity, decision, physical, other); it refuses every ask but a decision until the fifth part names what is open and filled (2026-10-31: six sign-ups were asked with no tab open, and two of the six turned out to have no Google button). If the same ask would come back, add the rule that removes it to OWNER.md under "Standing rules proposed by the agent" and let the NEEDS YOU end with "answer yes to make it standing".
   When the owner hands the click back ("you do it"), ask one yes or no question that names the action, the count and any cost ("Publish all 38 Etsy listings now? $7.60 in Etsy fees"), with a reply button worded as that action, then do it on the yes: a safety check lets a commit in a connected app through only when the owner's words name it (2026-10-30: "you do it on chrome" was refused, the named yes went through).
4. **Notify** if the owner may be away: Claude Code uses the PushNotification tool with that one line; a Codex automation notifies once. Never notify for "no change".
5. **When the owner says it is done**, verify it (log in, call the API, check the dashboard), finish what follows yourself (press a staged deploy, run the sync), mark the item done with the date, then ask for the next one.
6. **Secrets**: never ask the owner to paste a password, code or key into the chat. Ask them to sign in themselves in the browser tab, add the key to `.env.local` or the platform's variables, or use saved sign-ins or a credentials tool.

## Wording

Plain, specific, 30 seconds to read. Good: `NEEDS YOU (1 of 2): Railway -> open project "my-app", Variables, add RESEND_API_KEY from resend.com/api-keys -> unblocks F4 password reset email`. Bad: "You need to set up email, configure DNS and verify the domain." When the owner must choose, list the options in the message or an in-app question, never a file path to open.
