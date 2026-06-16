# User journeys — distilled from issues, so the simulation replays intent (not assertions)

Each issue is a *symptom*. Behind it is a **journey**: a persona with a goal, the
steps they took, where it broke, what they expected. Distilling the journey lets
us (a) replay it realistically, and (b) **generate tests they haven't filed** —
the adjacent paths of the same goal. New issues get folded into the journey they
belong to; if none fits, a new journey is added.

Every test follows the Definition of Done (see usability-sim.md): real role · real
surface · type → control appears → click → **reload → persisted** → console clean.
Status: **✅ ran & passed · ❌ ran & failed · ◻ proposed, not yet run.**

---

## J1 — Chapter Officer maintains the roster
**"I keep my chapter's people current — their available time, skills, resources —
and I trust my edits persist and show the same everywhere."**
Steps: People → open a member → change a field → expect it saved and visible later, on every page.
**Explains:** #10, #14, #26, #43, #44, #41, #40A, #40C.
**Tests generated:**
- ✅ Officer edits a member's **hours** → Save appears → reload → persisted (the #43 fix; fails on the old `type=number`).
- ✅ After editing hours, the **People roster** shows the new value (cross-page single source — ran: People showed `23/23 h/mo`).
- ✅ Officer changes a **skill level** (one-tap) → reload → persisted (different code path from hours — ran: Independent→Lead stuck).
- ✅ Officer can edit a **claimed member** in their chapter, not just cards (#44 — applies directly).
- ◻ Officer edits a member in **another chapter** → correctly blocked (allow/deny matrix).
- ◻ Editing a **resource** quota → review status visible → persists.
- **Found while distilling (unreported):** hours need an explicit **Save**, but skills save on one tap — *two save models on one card.* Likely-confusing; candidate fix = one consistent model (the audit's F1).

## J2 — Officer takes a consequential action and wants safety
**"When I assign / change status / finish / remove, I want clear feedback and a way back —
nothing silent or one-click-irreversible."**
**Explains:** #20, #31, #33, #35, #34.
**Tests generated:**
- ✅ status change / Finish / assign First Author → confirm gate + toast.
- ✅ Remove a seated person → seat frees, need reopens (reload).
- ◻ Every create/claim/assign/post has a reachable undo/remove (the create⇒delete matrix).
- ◻ Double-click a commit / save → no duplicate write.

## J3 — Member edits their own card (and it gets reviewed)
**"I update my own skills/hours; it goes to my officer; once approved it actually takes effect."**
**Explains:** #40B, part of #44.
**Tests generated:**
- ✅ Member self-edit → "pending review" chip + "submitted for review".
- ✅ Officer sees "Changes awaiting your review" → Approve.
- ❌/◻ **After approval, the member's value ACTUALLY changes** — must verify end-to-end (old habit: I checked "the panel cleared", not "the value applied"). *Caveat: the mock's decide handler only flips status; the real RPC applies. So this one needs a prod-or-fixed-mock run, not a mock pass.*

## J4 — A newcomer tries to understand and navigate
**"I arrive cold — I want to know where I am, what a thing means, what to do next, how to join."**
**Explains:** #16, #18, #19, #22, #42, #45, #46, #47.
**Tests generated:**
- ✅ Chapter panel shows description + "what joining means" to a non-officer (#47).
- ◻ **Cold-label pass:** a persona given only a plain goal picks the entry from nav labels alone; every control it meets has a visible label; flag any unlabeled glyph or ambiguous field (would surface #19 arrow, #42 cancel, #46 "name field", #45 "old system").
- ◻ Every form field answers "what do I put here?" without guessing (#46).

## J5 — Consistency & platform
**"One skill scale, one capacity number, the guide matches the UI, mobile/dark work."**
**Explains:** #17, #21, #29, #36, #40A/C.
**Tests generated:**
- ✅ One competency scale everywhere (#21); ✅ mobile row doesn't overlap (#36).
- ◻ Guide role-section ↔ reachable matching surface (#29).
- ◻ Run the whole of J1–J4 in **dark** edition (#17).

---

## Workflows are the unit (she tests by walking a role's whole job)

The right model isn't "probe control X for quality Y." She walks a **complete
workflow** — a real role doing a real task start to finish — and bugs surface where
the workflow breaks mid-stream. So the primary test is the **workflow**; the
quality checks (persist / delete / confirm / consistency) are just the steps that
can break *along the way*, asserted in context.

`workflows.spec.ts`:
| Workflow | The role's whole job | Steps it exercises |
|----------|----------------------|--------------------|
| **WF1** officer staffs a person | roster → open member → set skill & available time → **Save** → open the project need → **assign** (confirm) → on the **team** → reload-persists | #10/#14/#26/#43/#44 #33 #40A |
| **WF2** WG leader runs the record | open project → **add a task** (persists) → **advance status** (confirm gate) | #34 #35 |
| **WF3** member does their work | My tasks → find own task → **reopen** it → persists | #40B-adjacent |
| **WF4** researcher joins a unit | browse a working group → **read what it is** → **apply** → request goes pending | #47 |
| **WF5** WG leader closes out | advance → **Finish** (irreversible, danger confirm) → **settlement opens** | #35 + the Finish→Settle surface |
| **WF6** bipartite handoff | **WG leader** posts a need → **chapter officer (different person)** staffs it → team grows | the system's core design |
| **WF7** handoff reaches the member | chapter officer staffs her → **the member** logs in and is notified she joined | three distinct people, one collaboration |

**Coverage isn't just one persona doing different things.** WF1–5 / A1–9 / M1–3 were the
*same* few roles in isolation; the system's real shape is **distinct people handing off**
(chapters hold people, WGs hold projects, they meet at the need). WF6/WF7 are the first
that span people: WG leader → chapter officer → member. The next multi-person arcs to
encode: the member then *does the work* (WF3) and the WG leader *finishes & splits* (WF5)
— the full life of one project across all three actors; and the President's review job
(approve a submitted resource / settlement) as a fourth, distinct actor.

When a workflow breaks, that step is the bug she'd file. Walking WF-shaped task-board
steps is also what surfaced the real `task_remove` persistence gap (delete wasn't saved).

**Workflows still to encode** (each = a role's whole job): WG leader ships a paper (post
needs → staff → milestones → finish → settle) · resource steward (offer a resource →
review → it's offerable) · officer onboards a brand-new card (add person → set up →
first assignment).

## Who the persona actually is

Not a generic newbie. The testers are **officers who ran their group in a Google Doc**.
They know how to coordinate research; what they *lack* is this system's **invented
concepts**, and the bugs are the mismatch between their flat-doc model and these:
1. **The STR economy** — pools, accrual, settlement. Alien.
2. **Two kinds of group officer** — Chapter Officer (people) vs Working-Group Leader
   (projects). They don't know which they are or why it gates what they can do (→ #44).
3. **Custodial member-cards** — that "adding a person" creates a card you steward on
   their behalf until they claim it. A doc has rows, not custodial objects.

So the UI must **translate** each concept *where it's encountered*, not only in the guide.
`concepts.spec.ts`:
| Test | Concept the doc-user lacks | Bridge |
|------|----------------------------|--------|
| M1 | the STR economy | masthead STR now explains itself on hover (credit · accrues · settles · see Guide) — was a bare number with title "Open your wallet" |
| M2 | two officer types | the guide separates "If you run a chapter" vs "…a working group" (#28) |
| M3 | custodial cards | the "card" tag now explains it (you manage it on their behalf, like a doc row, until they claim it) — was an unexplained tag |

## The persona must also be LOW-compliance (or it finds nothing)

Jimin's catch: a goal-directed, compliant persona walks the happy path perfectly and
so **never hits her bugs** — she finds them precisely because she is *not* compliant:
she doesn't know the path, distrusts the UI, types junk, deviates. The workflow tests
above all pass because they're *told* where to click; that's their blind spot. So we
also run an **adversarial** persona (`adversarial.spec.ts`):

| Test | Low-compliance behaviour | Result |
|------|--------------------------|--------|
| A1 junk input "abc" in hours | types garbage into a field | ✅ clamps to a number |
| A2 negative hours | types -5 | ✅ not stored negative |
| A3 skeptic | distrusts the toast; navigates away and back in-app to re-check | ✅ persists |
| A4 whitespace task name | pastes "   " | ✅ Add stays disabled |
| **A5 explorer** | **zero goal-direction: scans the tabs to find where "available time" lives** | ❌ **found a real gap** — it was buried under a bare "Skills" tab; no label said availability/time/capacity (her #10/#14/#46 "where do I do X?" class). **Fixed**: tab relabelled "Skills & availability". |

| A6 impatient | double-clicks Save | ✅ no double-write / corruption |
| A8 cross-surface staleness | lowers availability, checks the matcher's free capacity | ✅ reflects the new value |
| **A9 cold start** | **a user who doesn't know what the system is FOR — lands on an empty community** | ❌ **found a real gap** — it showed "No projects match" (reads as "you searched wrong" to someone who never searched). **Fixed**: a first-run card — what this is + Start a project / Open People / Read the guide. |

### First login × the two officer types (the deepest lens yet)

The reporters are **not new** — they're officers who ran their group in a Google Doc, so
they arrive *knowing how to coordinate research* but **not** which of the two officer
types they are or what each one's home surface is. Walking a **first-login, low-compliance
officer** (one for each type, from a cleared session) surfaced an orientation gap the
single landing hides (`onboarding.spec.ts`):

| Test | First-login persona | Result |
|------|---------------------|--------|
| **ONB1 chapter officer** | lands on the **project ledger**, but her job is **people** | ❌ **found a gap** — "What needs you" only showed a people item *when people already had free time*; a first-timer (esp. an **empty chapter**) had **no path to her core people-job** — the only CTA, "Start a project", is the *other* officer's work. **Fixed**: the strip now always carries a chapter-roster entry ("Your chapter · N people" / "no people yet — add your researchers" → People). |
| **ONB2 WG leader** | lands on the project ledger — which **is** her home | ✅ already aligned — "Start a project" + "open needs on your projects" orient her; an empty WG already got the A9 first-run card. |

The asymmetry was the bug: an empty **working group** had the A9 first-run "Start a
project" card, but an empty **chapter** had nothing — a single shared landing (the project
ledger) silently favours one officer type. Fixed by making the people-steward's home
reachable from that landing too.

Two earlier lenses also found real gaps the compliant suite missed: **A5** (couldn't find
where availability lives) and **A9** (no orientation in an empty community — her #45/#47
"what is this / what do I do" class). The pattern holds: the *less* the persona knows and
the *less* it complies, the more it finds. **More lenses to add:** deviate mid-flow (open a
confirm, hit browser Back), wrong-terminology guesses (go to "Resources" looking for time),
abandon-and-resume a half-filled form.

## How this changes the loop
1. A new issue → find its journey (or add one) → restate the **intent**, not just the bug.
2. Replay the journey to reproduce — on the **current build**, as the **real role**.
3. From the journey, run its **generated tests** — including the un-filed adjacent ones; that's where we get ahead of the reporter.
4. A `◻` that, when run, fails becomes the next fix. A journey with no generated tests is a coverage hole.

The point Jimin made: don't store one bug as one script — distill the *operation behind the
issue* so the simulation is realistic **and** productive (it proposes the next test).

---

## Automated coverage (`npm run test:e2e` — Playwright on mock)

11 real-user tests, all green; proven to catch the #43 regression (red on the bug,
green on the fix). Each is a real-role / real-surface round-trip to the Definition of Done.

| Test | Journey | Issues |
|------|---------|--------|
| `roster J1.1` officer edits available time → Save → reload persisted | J1 | #10 #14 #26 **#43** |
| `roster J1.2` edited time matches on the People roster | J1 | #40A #41 |
| `roster J1.3` skill level (one-tap) persists on reload | J1 | #21 (scale) |
| `roster J3.1` member self-edit is told it went to review | J3 | #40B |
| `review J3.2` member submits → officer approves → value actually changes | J3 | **#40B** #44 |
| `project J2.1` status change asks to confirm (cancel = no-op) | J2 | **#35** |
| `project J2.2` Finish is gated by a danger confirm | J2 | #35 |
| `project J2.3` seated person has a Remove (undo) + confirm | J2 | **#33** #34 |
| `nav J4.1` root→/projects and Back doesn't bounce | J4 | **#24** |
| `nav J4.2` non-officer sees chapter context + "joining is reviewed" | J4 | **#47** |
| `nav J4.3` People is the roster, no bolted-on matcher | J4 | **#22** |
| `platform J5.1` one skill scale on the profile, no legacy badges | J5 | **#21** |
| `platform J5.2` mobile: status badge doesn't overlap the title, no h-scroll | J5 | **#36** |
| `platform J5.3` dark edition renders clean | J5 | **#17** |
| `perms J1.5a/b/c` officer & admin edit; a non-officer is read-only | J1 | **#44** #41 |
| `matcher J1.4` under-qualified candidate is flagged with the missing level | J1 | **#32** #31 |
| `ui J4.4` add-skill Cancel is a visible bordered button | J4 | **#42** |

**19 green** (`npm run test:e2e`). Still ◻: arrow meaning needs a label/tooltip then a test
(#19) · field-clarity (#46) and "still in the old system" (#45) need the reporter's screenshot to
pin the exact screen · guide↔UI cross-check (#29, tractable next: assert every guide "Your pages"
link resolves to a reachable surface).
