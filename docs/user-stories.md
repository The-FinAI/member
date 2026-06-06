# User stories — the two officers' jobs (HCI, goal-directed)

*Rewritten from the operators' real goals, not a feature walkthrough. Phase 1 has exactly two people who
log in: the **WG officer** (stewards projects) and the **Chapter officer** (stewards people). Each story
is **Goal → Scenario (their actual job) → HCI acceptance** (did they reach the goal without confusion,
know the next step, and get feedback). Test status: **R**=renders · **I**=interaction validated (mock) ·
**L**=logic (needs live `db push`).*

Personas:
- **Wang Fang** — WG officer, leads *Multilingual & Multimodal*. A grad student running a research group.
- **Chen Wei** — Chapter officer, *Beijing*. Secretary who staffs people onto work.

---

## A. WG OFFICER (Wang) — "run my group's projects, and credit the team when work lands"

### W1 — "What needs me in my group this week?"
**Goal:** open the app and immediately see where my attention is needed — no hunting.
**Scenario:** Wang signs in. Home should surface: projects with unowned tasks, open needs not yet filled,
and any finished project waiting to be split.
**HCI acceptance:** Home is a *triage list*, not a dashboard; each item is one tap to the right place;
if nothing's pending it says so. *(Test: R 🟡 — saw the router shell; the populated list needs real data.)*

### W2 — "Keep the project's record alive instead of the Google Doc" *(the heartbeat)*
**Goal:** maintain ml-Tagging's living record — tasks, owners, coverage, progress — in-app.
**Scenario:** Wang opens ml-Tagging, the **task board leads**. She adds "Collect KO filings", sets its
type and owner, flips "Confirm EN taxonomy" to Done, updates the XBRL coverage row.
**HCI acceptance:** add/assign/restate a task **inline, optimistically** (no full reload, no losing place);
coverage renders as a grouped checklist; the assignee is notified. The WG never opens the Doc.
*(Test: R ✅ board+coverage render; I ⏳ add/toggle not yet clicked; L ❌ notify/persist need live.)*

### W3 — "Tell the community what this project needs, and not post it blind"
**Goal:** declare an open role so a chapter can staff it — and know someone *can* fill it.
**Scenario:** Wang clicks **Post a role** → Annotation, Independent, 10h. After posting she sees
"~N people qualify."
**HCI acceptance:** one form (skill **or** resource); applies immediately (trusted officer); the
candidate-pool count makes demand non-blind. *(Test: R ✅ form renders; I ⏳; L ❌ pool count needs live.)*

### W4 — "Stand up a new project in under a minute"
**Goal:** start a project without ceremony or a bond.
**Scenario:** Projects → Start a project → name/type/proposal → Create. The first-author seat stays open.
**HCI acceptance:** free, no stake step; lands on a usable project page; first author is an open *need*
to be matched, not a hand-pick. *(Test: R 🟡; I ⏳; L ❌.)*

### W6 — "Advance the project as it progresses"
**Goal:** move the project through its lifecycle and record outcomes.
**Scenario:** Wang advances status Active → Under review when the draft is in; claims a milestone
(submission); adds the Arxiv link when it's out.
**HCI acceptance:** a single status pipeline; milestones/links update optimistically; the deeper project
admin (status · links · meetings · milestones · history) sits **below** the task board, not above it.
*(Test: R ✅ pipeline+milestones+links render; **I ✅ task-status flip optimistic** (same pattern); L ❌
status-advance/milestone persistence need live.)*

### W5 — "When the paper lands, split the credit fairly" *(highest stakes)*
**Goal:** distribute the finished project's credit so contributors are paid fairly.
**Scenario:** Wang finishes the project, opens Split — weights default to each person's logged hours, a
**fairness line** flags anyone who did a lot but is set to get little.
**HCI acceptance:** the highest-stakes moment is the **best-supported** (defaults + fairness check +
contribution visible), not a bare weights form; STR is loud *here* and quiet elsewhere.
*(Test: R ❌ not yet; I ❌; L ❌ — must verify before first real settlement.)*

---

## B. CHAPTER OFFICER (Chen) — "keep my people current, and get them placed on the right work"

### C1 — "Register a new member with their skills and time"
**Goal:** add a person so they can be matched.
**Scenario:** People → Add a person → name/email/affiliation → then on their card set skills
(Annotation · Independent) and capacity (20h).
**HCI acceptance:** add is one short form; skills are a **one-tap level** (no badge tree/exam); capacity
is a plain attribute; edits apply immediately with undo. *(Test: R ✅ form+skill editor render; I ⏳; L ❌.)*

### C2 — "Keep skills honest and current"
**Goal:** a person's level reflects reality, trustworthy to a WG that staffs them.
**Scenario:** as Li owns more annotation tasks, the system suggests "mark Independent?"; Chen accepts.
**HCI acceptance:** level is **behaviorally anchored + evidence-backed** (`4 tasks · 2 shipped`), earned
not granted; no unanchored self-rating. *(Test: R ✅ evidence shows; I ⏳ raise-suggestion; L ❌.)*

### C3 — "See who's free, and place them onto open work" *(the daily job / the seam)*
**Goal:** match my roster onto the community's open needs without over-committing anyone.
**Scenario:** People → Match board → pick the Annotation need → ranked candidates show level, evidence,
**free capacity**; Chen assigns Li 6h; tries to over-book Li and is stopped.
**HCI acceptance:** **select→glow→click**, one gesture; capacity is a **visible bar that turns red before
it blocks** (constraint visible before the wall); under-level people still show, ranked lower; resource &
first-author needs match the same way; the person is notified. *(Test: R ✅; **I ✅ capacity guard
validated** — red bar + disabled Assign at over-book; L ❌ ranking/notify need live.)*

### C5 — "Register what compute/data my people can contribute" *(resources)*
**Goal:** record the GPU hours, datasets, APIs or funding a person holds, so projects with resource needs
can be matched to them — contribution isn't only hours.
**Scenario:** on a member's **Resources** tab, Chen declares "A100 ×2 · 200 GPU-hours/mo". A WG posts a
**GPU need**; on the Match board the GPU need lists **holders ranked by remaining quota** (unit-aware),
and Chen assigns one.
**HCI acceptance:** declaring is one type-adaptive form (GPU/API/dataset/funding); the resource need
matches by **who holds it + remaining quota** (not skill); "My time" is NOT a resource (it's capacity).
*(Test: R ✅ supply form + need both render; **I 🟡** quota-bar shown; L ❌ resource match/quota gate need live.)*

### C4 — "Make sure no one is idle or overloaded"
**Goal:** scan the roster and see free vs committed at a glance.
**Scenario:** People roster — each person shows a capacity bar (used/total this month).
**HCI acceptance:** the one number an officer scans (free hours) is visible per person; Home flags
"N people have free time." *(Test: R 🟡 capacity shown as text/bar; I ⏳; L ❌ Home free-count needs data.)*

---

## What the local mock CAN and CANNOT validate
- **CAN (interaction-layer HCI / §13 DoD):** optimistic update (no reload), inline feedback, the capacity
  bar turning red before the disabled Assign, modeless select→glow, enabled-or-explained, layout/vocab.
  *(C3's capacity guard is proven this way.)*
- **CANNOT (logic correctness):** real match ranking, the capacity/quota gate server-side, first-author
  hour minting, assign→notification delivery, settlement payout, person_skill backfill — these need a
  live `db push` and a real session.

## Test plan (interaction sweep, in officer-job order)
1. **W2** add a task + flip a state → watch optimistic, no reload (next).
2. **C1** add a skill one-tap; **C2** accept a raise suggestion.
3. **C3** click Assign on a valid candidate → consequence feedback; open the 🔔 to see the notification.
4. **W3** post a role → pool count. **W5** open Split → fairness line (needs a finished project).
