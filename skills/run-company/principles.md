# Principles for big jobs

What makes big projects work across business, engineering, science and design, distilled into what this harness does about each. Read it at a company's or product's setup, before a big bet (a new product, edition, channel, price or paid spend) and in the weekly review. Research of 2026-10-30; every line names its source. The skills enforce the starred lines; the rest are for judgment.

## Decide what to build

| Principle | Source | What the harness does |
|---|---|---|
| Work backwards from the customer: write the launch-day press release and the hardest FAQ before building | Amazon PR-FAQ (Bryar and Carr, Working Backwards) | * product-spec starts PRODUCT.md with a five-sentence press release and three hard FAQ answers; if it does not convince, change the product first |
| Pick markets that are large, early and desperate; follow the money to who already pays for the problem | Michia Rohrssen, "Give Me 24 Minutes, I'll Teach You to Build a $1M Startup with AI" (chapters: Follow The Money, The Vehicle Filter, Large, Early, Desperate) | Idea rows in run-company and portfolio score these three before any build |
| Effectiveness first: do the right things, then do them right | Drucker, The Effective Executive | * every row names what it serves; rows that serve nothing are cut (existing rule) |
| Value = dream outcome x likelihood / (time delay x effort) | Hormozi, $100M Offers (use as a copy checklist, not a predictor) | Offer and landing copy states the outcome, the proof, the time to the first result and the effort removed |

## Bet small, learn fast

| Principle | Source | What the harness does |
|---|---|---|
| The unit of progress is validated learning, not features | Ries, The Lean Startup | * a bet row names its hypothesis, the number that decides it and the read date; it is verified only when the number is read and says keep, change or kill |
| Know what you are testing; test options side by side | Rohrssen (chapters: Know What You're Testing, Test Side-by-side) | Bets run as two or more variants at once when the channel allows, each with its own number |
| Do things that don't scale: go out and get the first users by hand | Paul Graham, Do Things That Don't Scale | * with zero outside visitors or sales, distribution outranks more product: direct outreach to real people and one measured channel come first |
| Know whether you are default alive or default dead | Paul Graham, Default Alive or Default Dead? | The weekly review computes runway from Money; when default dead the next row is a revenue or cost fix |
| Fixed appetite, variable scope; no silent extension | Shape Up (Basecamp, Singer) | A row that blows its time box is shipped as is, cut, or re-shaped as a new row, never quietly continued |
| Scale vertically, then horizontally: win one narrow segment before adding the next | Rohrssen (chapter: Scale Vertically, Then Horizontally); Graham on starting narrow | Expand to a new category only after the first one has paying customers |

## Plan like engineers

| Principle | Source | What the harness does |
|---|---|---|
| Think slow, act fast; forecast from a reference class, not the plan | Flyvbjerg and Gardner, How Big Things Get Done | Due dates come from past rows of the same kind in runs.log; a row with no reference class is marked a guess |
| Pre-mortem: assume it failed, list why, change the plan | Klein, Performing a Project Premortem (HBR 2007) | * before a big bet, three "this failed because" lines become rows, guards or non-goals |
| Rank risks by severity first; a failure you cannot detect needs a monitor | FMEA (AIAG-VDA 2019 severity-weighted priority) | A risk the harness could not detect gets a monitoring row before more features |
| Test as you fly: verify in the real configuration | NASA GSFC GOLD Rules 1.08 and 1.09 | * verified needs evidence from the real surface (existing rule); a non-production check is logged as an exception |
| Short checklists of killer items at fixed pause points | Gawande, The Checklist Manifesto | release-gates is a do-confirm list run before deploy, store submission and "done" |
| State pass criteria before the test; log every deviation | Preregistration (Nosek, Center for Open Science) | QA rows hold the expected result before the run; changing it afterwards is a logged deviation |
| One coherent design; adding workers to a late job makes it later | Brooks, The Mythical Man-Month | Late jobs never get more parallel workers; one spec, one owner of it |
| Error budget: when reliability is spent, only reliability work ships | Google SRE, Embracing Risk | A product with failing health or QA gets only fix rows until it passes (stop the line) |
| Stop the line on an abnormality | Toyota Production System (jidoka, andon) | A failing gate blocks new rows on that track until fixed or explicitly cut |
| Blameless postmortems: most failures are system causes; do not tamper on one bad run | Google SRE; Deming, Out of the Crisis | Lessons name a rule, script or skill (learn skill); one sighting is noise unless it cost a run or an owner ask |
| Single-threaded owner per job | Amazon (Wilke, in Working Backwards) | One owner per row (existing rule) |
| Two-way doors are decided fast and logged; one-way doors get a memo and the owner | Bezos, 2015 shareholder letter | Reversible choices are the agent's; money, legal, identity, public launch and deleting data go to the owner with options (owner-actions) |

## Design and decide

| Principle | Source | What the harness does |
|---|---|---|
| Understand the problem before solving it; test small, drop what fails | UK Design Council, Double Diamond | product-spec writes who is affected and the reframed problem before flows |
| Less, but better; honest | Dieter Rams, ten principles | * every claim in copy maps to a verified fact; no unearned social proof (ux-ui-review) |
| Visible signifiers and immediate feedback for every action | Norman, The Design of Everyday Things | ux-ui-review checks feedback and empty, loading and error states (existing) |
| Focus is saying no; non-goals are written down | Jobs, WWDC 1997 | PRODUCT.md lists non-goals; mid-run ideas go to a "not now" line, not new rows |
| Above all show the data | Tufte, The Visual Display of Quantitative Information | Reports are numbers with evidence links, no decoration standing in for data |
| Commander's intent: say the why and the limits, let the executor choose the how | US Army ADP 6-0, Mission Command | * every worker prompt carries the goal, what its row serves and the OWNER.md limits; deviations that serve the intent are allowed and logged |
| Shared consciousness plus empowered execution, never one without the other | McChrystal, Team of Teams | One ledger every worker reads before acting and writes before stopping (existing) |
| Judge decisions by their process at the time, not by how they turned out | Annie Duke, Thinking in Bets | * Decision lines record the expected result and confidence, so the review grades the bet, not the luck |
| Check incentives first; invert: how could this fail? | Munger, The Psychology of Human Misjudgment | Hire and partner rows say who is paid for what; release gates are written as failures to prevent |
| Log every mistake; weight claims by track record | Dalio, Principles | note.sh is the issue log; a claim backed by verified rows beats a confident guess |
| Throughput and stability rise together | DORA, Accelerate (Forsgren, Humble, Kim) | A faster release pace that raises failed deploys counts as a regression |
| Fast layers learn, slow layers remember | Stewart Brand, pace layers | A run changes rows, scripts and products; rules and OWNER.md change only in the weekly review |

## Do not adopt

- Survivorship stories with revenue and time promises ("$1M in 24 minutes"): keep the method, ignore the numbers.
- "Planning is waste, just start": Flyvbjerg's 16,000 projects say poor planning is the main cause of failure.
- More parallel agents for a late job: Brooks's law.
- 100 percent reliability or zero defects as a target: Google SRE, each increment costs more than it returns.
- Changing the harness after every single bad run: Deming calls reacting to common-cause variation tampering.
- OKR stretch grading and one-number risk scores (RPN): a row is verified or not; sort risks by severity.
- Padding estimates instead of using a reference class (Kahneman): a buffer on a biased number stays biased.
- Full autonomy without the shared ledger, or "faster loops always win" (McChrystal, Boyd's commentators): orientation and the shared picture decide, not raw speed.
- Minimalism for its own sake (Tufte's decoration rule): honesty and data first; decoration did not hurt comprehension in tests.
