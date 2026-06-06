# The Fin AI Community — Final PRD (HCI-corrected)

*The single source of truth for the rebuild. It consolidates and **supersedes** `north-star.md`,
`phase1-officer-reality.md`, and PRD-hci §1–13. The reasoning trail (HCI principles, deeper friction,
micro-interaction logic, the WG-record reality check) lives in `redesign-hci.md` §11–14; this PRD is the
**decision**. Anything not expressible here should not be built.*

---

## 1. Product & phases

**The Fin AI Community is the operating system of a research community: it runs the *working groups'*
projects and the *chapters'* people, and turns finished work into settled credit (STR).**

- **Phase 1 (now): an operating tool for officers.** The only people who log in are **officers acting as
  proxies** for members who can't yet. Hero = *their projects and their people.* STR is a quiet
  background ledger.
- **Phase 2 (later): a contribution wallet for members.** Members log in and act for themselves. Hero =
  *my tasks, my contribution, my STR.* **Same data, the point of view flipped.** Every Phase-1 surface
  is designed so the member view is its other mode, not a rewrite.

The first job to win: **make the working group's Google Doc obsolete** — the WG opens the app and finds
its living record already inside (§5.2, §8).

---

## 2. Users & roles — two domains, two stewards

The org is **bipartite**, and the product mirrors it exactly:

| Role | Stewards | Domain | What they do |
|---|---|---|---|
| **President / Admin** | the whole org | both | full authority; runs the economy & catalogs; the value-review inbox |
| **WG officer** (Group lead) | a **Working Group** | **Projects** | create/claim projects · **resource a project** (matching) · run it as a **task board** · Finish → Split credit |
| **Chapter officer** (Secretary) | a **Chapter** | **People** | register people · certify skills · steward the **roster** (capacity) · supply people into open roles |
| **Researcher** (member) | themselves | personal | (P1: represented by a card) · (P2: owns tasks, contribution, wallet) |

A person can hold more than one role; they then steward more than one surface — **never a merged home.**
Permissions are shown as **named groups**, never raw keys: *Approve credentials · Manage people & access
· Manage projects · Manage skills & catalog · Manage resources · Run the STR economy.*

---

## 3. The object model — bipartite, two logics, one seam

```
   PEOPLE DOMAIN  (Chapter / Chapter officer)        PROJECTS DOMAIN  (Working Group / WG officer)

   Chapter ─ Person                                  Working Group ─ Project
              • skills (level + provenance)                          • emoji · code (e.g. ml-Tagging) · status
              • capacity (hours / month, time-phased)                • Proposal / Arxiv / References (links)
              • contribution / credit (quiet)                        • Milestone (lifts payout)
                        ╲                              ╱   ┌─ Role  (formation: a needed skill/resource)
                         ╲    ── the only seam ──     ╱    └─ Task  (execution: name · owner · status · note)
                          ╲   match person → Role    ╱
                                       ↓
                            Contribution → Finish → Split → STR   (the ledger; legible but quiet)
```

**Six nouns:** Person · Project · **Role** · **Task** · Milestone · STR. Plus the two containers,
**Chapter** and **Working Group**. If a feature can't be said with these, it probably doesn't belong.

### 3.1 The two logics (the central correction)
A project lives through **two distinct logics at two stages — both required, cleanly split:**

1. **Forming a project = resource matching.** Declare what the project needs (a **Role**: a skill at a
   level, or a resource, with a capacity), and **match** people/resources against it (qualify · capacity
   · seat). A project doesn't run until it's resourced. *This is the §0–13 seam — the gate that staffs a
   new project.*
2. **Running a project = direct assignment.** Once staffed, the lead breaks work into **Tasks** and
   **assigns owners directly** (pick a teammate, or leave TBD). No skill gate, no matching ceremony —
   "this person, this task." *This is the WG doc's living record.*

**Role ≠ Task.** Matching produces the **team**; tasks organize **the team's work**. They are different
objects on different layers. (The real WG doc shows only logic #2 because its projects were already
formed — matching happened earlier, off-page.)

### 3.2 Definitions (final)
- **Person** — a researcher; in P1 a **card** a Chapter officer manages. Has **skills** (each at a level
  *with provenance* — certified-by/​self-claimed) and **capacity** (hours/month, shown **per period**).
- **Project** — a unit of work toward a publication, owned by one Working Group. Carries emoji · code ·
  status · Proposal/Arxiv/References · its team (from Roles) · its Tasks · its Milestones.
- **Role** — a need a project declares at **formation**: a skill+level, or a resource, with a capacity.
  Filled by **matching**. Produces project membership.
- **Task** — a unit of work at **execution**: `{ group?, name, work_type?, owner?(TBD=open), state, note }`.
  Assigned **directly**. `state` ∈ {Open · Doing · Done} (coverage groups may use Confirmed/Checking/
  Potential). `work_type` is a small configurable list (Annotation · Raw Data Collection · Evaluation …).
- **Milestone** — an achievement (submission/acceptance/release) that lifts the project's payout (≤ ×3).
- **STR** — the credit. **Accruing** (locked, while work happens) → **Paid** (liquid, after Split).
  Shown only as *credit ≈ N* with a one-tap "how computed"; never the hero in P1.

---

## 4. Information architecture — surfaces

| Surface | Domain | Everyone | The steward adds |
|---|---|---|---|
| **People** | Chapter | browse people & chapters | Chapter officer: **roster** (capacity bars) + supply people into open Roles |
| **Projects** | Working Group | browse projects & groups | WG officer: **resource** a project (formation) + run its **task board** (execution) |
| **My** | personal | my card · my tasks · my contribution · wallet | — (quiet in P1; the **hero in P2**) |
| **Directory** | reference | chapters · groups · badge catalog | — |
| **Settings** | governance | — | Admin: **one Review inbox** (value/cross-seam only) + catalog editors |

**Home is a thin, role-aware router** — not a dashboard. It opens onto a **"what needs me"** triage list
scoped to your role(s): *WG* — "project X finished → Split · a Role you posted is fillable · 3 open
tasks unowned"; *Chapter* — "2 Roles your people fit · 1 person just freed up · 2 awaiting review."
There is **no merged player-coach lane**; a dual-role user sees both surfaces, each clean. Target: from
~20 routes to **5 surfaces.**

---

## 5. The core flows (decisive)

### 5.1 Form & resource a project (WG officer · logic #1)
Create project (free, no bond; emoji · code · type · proposal) → declare its **Roles** (skill+level / a
resource, with capacity & headcount) → for each Role, **match**: see qualified people **with their spare
capacity** and *why they fit*, **assign** in one in-place confirm. At post time the WG sees the
**candidate-pool size** ("~4 people qualify") so demand is never posted blind. Output: a resourced team.

### 5.2 Run a project — the living record (WG officer · logic #2) — *replaces the Google Doc*
The Project page **is** the doc's per-project section:
- **Task board** — inline-editable `Task · Type · Owner · Status · Note`; add a task = one row; assign
  owner = pick a teammate or TBD; change state = click the cell.
- **Coverage checklist** — a task **group** (e.g. language × state × owner) for matrix projects.
- **Links** — Proposal · Arxiv · References. **Rich body** for prose.
- **Cross-cut views the doc can't give:** all **open/TBD** tasks across the WG (the backlog) · **my**
  tasks across projects (the P2 member hero) · by owner · what changed this week.

### 5.3 The seam — match a person into a Role (Chapter officer)
**One gesture**, on the People surface: select a person → fitting Roles glow, each showing the person's
**spare capacity** and the **positive reason** they fit; click → inline confirm pre-filled to
min(free hours, need) → **Assign**. Mirror: select a Role → qualified people glow, dimmed-with-reason if
short. Assigning to a project with no matching Role just creates the Role behind the scenes (same gesture,
permission-gated). **Select→glow→click is primary; drag is an optional accelerator** (never the only path).

### 5.4 Finish & split credit (WG officer)
Finish → the **Split** form defaults each contributor's weight to **their logged hours over the project's
life**, shows a **fairness summary** (shares = 100%; flags "big contributor, tiny share"), and surfaces
**contribution history** beside it. Submit → review → STR paid. The highest-stakes moment is the
best-supported one.

### 5.5 Register a person (Chapter officer)
Add a card: name · email · affiliation · **hours (a person attribute, not a "My time" resource)** ·
skills (each level carries a rubric + becomes a badge after review). Edits to your own roster apply
**immediately, with undo**.

---

## 6. Interaction principles (Definition-of-Done for every screen)

Distilled from `redesign-hci.md` §11/§13 — enforce these, not just the layout:

1. **Two domains, never merged.** People-screens show people; project-screens show projects; they meet
   only at the Role. *(Norman conceptual model; Nielsen #2.)*
2. **One concept = one word = one component = one gesture.** No duplicate forms, no synonym buttons.
3. **Direct manipulation.** Matching & assignment are select→glow→click; only valid targets are
   actionable. *(Shneiderman/Hutchins–Hollan–Norman; information scent.)*
4. **Make the constraint visible before it blocks.** Capacity is a **bar, time-phased** (this month /
   next). Never a mystery-greyed button — **enabled-with-guidance**: state the one blocking reason and
   the fix, at the field. *(Nielsen #1/#5.)*
5. **No reload-everything.** Actions update **optimistically, in place**; scroll, selection, and open
   pickers **survive** every act. *(Doherty threshold; the single biggest as-is debt.)*
6. **Validate live, inline, one reason at a time** — at the field, while typing; never a dumped error
   string at the form top. **Preserve input + Retry** on failure; translate Postgres errors to plain
   guidance.
7. **Trust + undo, tiered review.** Own-domain edits: **immediate + toast-undo**. Cross-seam acts
   (place into another group's project; claim a project): a **handshake** the receiving steward accepts.
   Value acts (badge grants, settlement payout): the **admin Review inbox**. Guard the truly irreversible
   (hard delete) with confirm-or-undo. *(Nielsen #3; Shneiderman #6.)*
8. **Design for the 20th action.** Full keyboard path (type-ahead, Enter/Esc, Tab order), **smart
   defaults** (zero-typing common case), **batch** where the work is batchy (matching, not just badges).
9. **Legibility of the economy & of skill.** STR shows as *credit ≈ N* + "how computed" (hours × rate);
   resources/Roles show a **live valuation preview**; every skill level carries a **rubric + provenance**.
10. **Feedback & social state.** Every act shows its **consequence inline** and **notifies** the people
    affected. An assignment is a **proposal with state** (proposed → active), notified to the assignee —
    no silent conscription; P2 turns it into accept/decline.
11. **One object pattern.** Card → drawer (peek) → route (deep). Never a drawer hosting a full tabbed
    body. Opening a related entity **peeks without losing the parent** (no pogo-sticking).
12. **First-class empty / loading / error states**, and a **notification inbox** (+ optional email) as
    the async spine.

---

## 7. Vocabulary (final — enforced in nav · buttons · copy · admin · tooltips)

| Banned | Use |
|---|---|
| slot / open_need / work_labor | **Role** (formation) |
| (the doc's informal todo) | **Task** (execution) |
| seat / bind / forge / seat_direct | **Assign** |
| "My time" resource / monthly_quota | **Hours / capacity** (a person attribute) |
| nominal / liquid STR (as hero) | **Accruing / Paid credit**; STR is the unit, not the headline |
| Mint done / settle / harvest | **Finish → Split the credit** |
| apprentice…master | **Beginner · Intermediate · Advanced · Expert** (DB keeps ranks; UI never shows old words) |
| Forge queue | **Review inbox** |
| Chapter · Working Group | **keep** — the two domains are the IA spine |

---

## 8. What's new / changed / removed vs today

**New**
- **`Task`** (execution primitive) + the **WG living-record project page** (task board · coverage · rich
  body) + **Google-Doc import**.
- **Capacity as a time-phased attribute** of a Person; **provenance** on skill levels; **live valuation**.
- **"What needs me"** home; **notification inbox**; **assignment-as-proposal** state; **toast undo**.

**Changed**
- Officer **Console splits** into the steward views of **People** and **Projects** (no merged console).
- **Matching becomes one gesture** (select→glow→click) and is scoped to **project formation**; the as-is
  3 seating UIs + `work_seat`/`seat_direct` collapse behind one `assign()`.
- **Review** goes from queue-everything to **tiered** (immediate+undo / handshake / admin-value).
- **STR** moves from home hero to quiet, legible credit.

**Removed**
- The STR-ring mining home; duplicate forms (`ForgeCard` need+badge); the dual-body project rendering;
  legacy `saveLabor`/`addResource`; "My time" resource modeling.
- The **6 dead backend subsystems** (token economy, apply→accept→confirm join, stake commitments,
  skillcards, skill-exam+endorsement, resource offers, paid-leader bonds) → one legacy-purge migration.
- ~15 legacy admin routes → folded into Settings. Target: **5 surfaces · ~8 components · 6 nouns.**

---

## 9. Rollout — in the order the WG *lives* it (each step reversible)

0. **Execution record first** — `Task` model + WG living-record project page + **doc import**. The
   thing they open weekly; lightest; immediate "drop the doc" value. *(§5.2)*
1. **Legibility & "what needs me"** — credit-≈ + how-computed, time-phased capacity, the triage home.
   Cheapest trust wins.
2. **Language & dedup** — §7 vocabulary; collapse duplicate forms to single components (pure relabel +
   delete).
3. **Split the console → People + Projects surfaces**; Home as role router.
4. **One matching gesture + visible capacity** behind one `assign()` — the **formation** seam (§5.1, 5.3).
5. **Social spine** — assignment-as-proposal + notification inbox (unlocks P2; removes conscription feel).
6. **Supported Split** (§5.4) before the first real settlement.
7. **Cull** — legacy-purge migration · routes ~20→5 · the two near-universal interaction refactors
   (kill reload-everything; enabled-or-explained + live-inline validation).

---

## 10. Success metrics & acceptance

**Adoption:** the Multilingual&Multimodal WG **stops editing its Google Doc** and maintains its record
in-app (the north-star metric). New officers self-serve without a walkthrough.

**Acceptance test (any screen must pass all):**
> A **WG officer** opens **Projects**, sees their group's projects exactly as their doc, edits a task,
> assigns an owner, later clicks **Finish → Split**. A **Chapter officer** opens **People**, sees the
> roster with capacity bars, and staffs a forming project's Role by select→glow→click. Neither manages
> the other's domain; neither meets *slot · forge · nominal · seat · harvest*; neither hits a grey button
> that won't say why; neither loses their place after acting; and each can answer without asking anyone —
> *what is this credit worth · when is this person free · what happened after I acted · does the
> researcher know.* If a screen mixes a person's **own** projects with their **team**, or one act needs
> two forms, or the WG still needs the doc — it is pointed at the wrong structure and must be fixed.

---

## 11. Open questions (validate with real users, don't assume)
1. **Formation matching in practice** — do WG leads actually want skill+level+capacity gating to resource
   a project, or do they just name people? Test before building the full qualify machinery (§5.1).
2. **Coverage vs Task** — is the language-coverage matrix better as a task *group* or its own light
   object? Watch real use.
3. **Chapter ↔ WG handoff** — when a WG needs people, does the Chapter officer *push*, or does the WG
   *pull* ("who can do this?")? §5.3 supports both; observe which is primary.
4. **Credit weights** — are logged hours a fair default, or do WGs decide by negotiation? §5.4 defaults
   to hours but must stay editable.
