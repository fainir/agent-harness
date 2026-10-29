---
name: hire
description: Hire and manage people online when a step needs a human - freelancers, contractors, virtual assistants, designers, writers, video editors, callers, local agents, testers, lawyers, accountants - on Upwork, Fiverr, Contra, Freelancer, Toptal, LinkedIn or a local board. Writes the brief and the job post, screens and interviews by message with a scorecard, sets milestones, onboards with least-privilege access, reviews deliverables like your own work, and hands the owner only the clicks they must make (fund escrow, approve a milestone, sign). Triggers on "hire", "find someone to", "get a freelancer", "outsource", "I need a human for", "virtual assistant", "get a designer / writer / editor", "תשכור", and /hire.
---

# Hire a human

Humans are a tool you use when you cannot do the step yourself or the owner asked for a person. You stay accountable for the result: you brief, you review, you accept.

## When a human is the right tool

A voice or a body (calls, site visits, deliveries, filming), a licence (lawyer, accountant, notary), a native speaker for a language you cannot verify, a style or taste the owner wants from a person, volume you cannot reach in the time (data labelling, 200 calls), or owner-only chores the owner wants delegated to an assistant. Try it yourself first; the row says in one line why a human is needed.

## Owner-only steps (always)

Creating or verifying a platform account; funding escrow; approving a milestone payment; signing a contract; giving a human access to a real account (you prepare least-privilege invites, the owner clicks). Inside the OWNER.md hiring caps you may post jobs, message candidates and set up milestones; money still moves only by the owner's click.

## Process

1. **Brief** `hires/<role>-<slug>.md` from `templates.md`: outcome, deliverables with acceptance criteria, deadline, budget (from OWNER.md), inputs you give, access they get, how you will review. Add the row to COMPANY.md (Tracks and People) or READINESS.md with status `human (hiring)` and why a human.
2. **Platform** by task (table below). Prefer one where the owner already has an account (a credentials tool); otherwise NEEDS YOU: create the account.
3. **Post**: the job post from the brief (title, outcome, deliverables, budget type, timeline, two screening questions). Posting is public: do it when OWNER.md allows job posts on that platform, else NEEDS YOU with the post ready to paste. Record the posted job in `.runtime/hires-state.json` so it is never posted twice.
4. **Screen** every applicant with the scorecard (relevant sample, clarity of the reply, answers to the screening questions, rating and history, price against the cap). Top three get the interview message (five questions). A paid one-hour test task when the budget allows and the work is subjective.
5. **Choose** and set up the contract on the platform: fixed price with milestones, acceptance criteria copied from the brief, a deadline per milestone. NEEDS YOU: fund the first milestone.
6. **Onboard** in one message: the brief, the inputs, scoped access (repo invite, shared folder, a test account; never the owner's passwords, never production customer data), where to ask questions, the dates.
7. **Manage**: the row carries the due date; check in once mid-way and on the due date, not daily. Answer questions within a day. Scope changes are a new milestone, never "also do".
8. **Review** the deliverable like your own work: qa-flows or ux-ui-review for product work, the acceptance criteria for everything else. One specific fix list with a date, at most twice. Then accept, or end with a reason.
9. **Pay and close**: NEEDS YOU: approve the milestone. Leave a fair review. Record in `hires/log.md` (who, what, cost, quality 1 to 5, hire again) and the People table. Remove access.

## Platforms (default picks)

| Need | Platform | Typical price |
|---|---|---|
| Small defined task (logo, ten edits, data entry, a voice-over) | Fiverr | $20 to $200 |
| Part-time professional (developer, designer, writer, VA, support) | Upwork, Contra | $15 to $80 per hour |
| Senior specialist | Toptal, Contra | $80 and up per hour |
| Calls, local errands, physical presence | Upwork with a location filter, TaskRabbit, local boards | hourly |
| Lawyer, accountant | local directory, the owner's referrals | fixed quote |
| Testers and user panels | UserTesting, Prolific | per session |

## Communication

Short, polite, one clear ask per message, a date in every message, everything inside the platform (escrow and dispute protection), no secrets, no customer personal data. Write in the candidate's language when the company serves that market.

## In the report

`People: <name> (<role>) - <status> - due <date> - <cost so far> of <cap>` inside the company report. Owner clicks use the NEEDS YOU format.
