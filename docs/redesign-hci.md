# Rebuild from HCI — the decisive blueprint (v2: bipartite)

*v1 of this doc made a structural error: it merged "my projects" and "my people" into one
**Bench** (a player-coach two-lane home). That is wrong. **People and Projects are two separate
domains, governed by two separate officer roles**, and they touch at exactly one seam. This v2
rebuilds the whole redesign around that separation. Supersedes `north-star.md`,
`phase1-officer-reality.md`, PRD-hci §1–13, and v1, grounded in the as-is map (`interaction-detail.md`).*

---

## 0. The correcting insight

> **The org is bipartite. People live in Chapters; Projects live in Working Groups. These are two
> separate axes with two separate stewards — and the *only* place they meet is the open Role.**

| Domain | Container (org unit) | Steward | Objects | The job |
|---|---|---|---|---|
| **People** | **Chapter** | **Chapter officer** | Person (skills · capacity) | register people · certify skills · **place them into open roles** (matching) |
| **Projects** | **Working Group** | **WG officer** | Project · Role · Milestone | create/claim projects · **post what they need (roles)** · run to Finish · split the credit |

The two never share a screen except at the **seam**. v1's two-lane Bench violated this by mixing a
person's own projects with their team on one home. v2 keeps the domains apart and makes the seam explicit.

---

## 1. The object model — bipartite, one seam

```
   PEOPLE DOMAIN                                    PROJECTS DOMAIN
   (Chapter — Chapter officer)                      (Working Group — WG officer)

   Chapter                                          Working Group
     └─ Person                                        └─ Project
          • skills (at a level)                            • status (lifecycle)
          • capacity (hours / month)                       • Milestone (lifts payout)
          • credit so far (quiet)                          └─ Role  ← demand, posted by WG
                         ╲                              ╱        (a skill+level, or a resource)
                          ╲                            ╱
                           ╲——— THE SEAM: MATCHING ———╱
                            Chapter officer assigns a Person → an open Role
                                          ↓
                              Contribution  (the person's monthly hours on that role,
                                             valued in STR — the ledger, kept quiet)
                                          ↓
                              Finish → Split  →  STR  (credit becomes real only here)
```

- A **Person** belongs to exactly one **Chapter** (their home unit). Chapters *contain people*.
- A **Project** belongs to exactly one **Working Group**. Working Groups *contain projects*.
- A **Role** is **exposed by a project** (WG posts it) and **filled by a person** (Chapter places them).
  The Role is the *contract surface* between the two domains — the one shared noun.
- **Contribution → Finish → Split → STR** is the value pipeline; STR is the ledger unit, never the hero.

**The seam is a two-sided market:** WG officers post **demand** (open roles, community-wide);
Chapter officers supply **labor** (their roster) by matching people into those roles.

---

## 2. Surfaces — organized by domain, filtered by role

From ~20 routes to **4 + Settings**, each surface owning **one** domain:

| Surface | Domain | Everyone sees | The steward additionally does |
|---|---|---|---|
| **People** | Chapter | browse the directory of people & chapters | **Chapter officer:** their roster (skills + capacity bars) **and the Matching board** (place roster → open roles) |
| **Projects** | Working Group | browse all projects & groups | **WG officer:** their group's projects — create/claim, **post roles**, run pipeline, **Finish → Split** |
| **My** | personal (researcher) | my card · my contributions · wallet (STR) — *quiet in P1, the hero in P2* | — |
| **Directory** | reference | chapters · working groups · badges catalog | — |
| **Settings** | governance | — | **Admin:** one **Review inbox** + catalog editors (skills · types · roles · venues · economy) |

**No merged "Console."** The old officer console split cleanly in two: its **people+matching** half is
the steward view of **People**; its **projects** half is the steward view of **Projects**. A person who
is *both* a Chapter officer and a WG officer simply has steward powers on *both* surfaces — never a
mashed-together home. **Home** is a thin router: it sends you to the surface(s) you steward, with the
matching board front-and-centre for chapter officers and the project worklist for WG officers.

---

## 3. The seam — matching, designed as one gesture (People surface, Chapter officer)

This is the product's beating heart, and today it is the worst offender: **3 UIs + 4 RPCs** for one act
(`SlotSeater` on the project page, `MatchConsole` inline seat, `SlotSeater` "Add directly";
`work_seat`/`seat_direct`). Rebuild it as **one gesture on the People surface**:

1. The Chapter officer sees two columns: **my roster** (left, each person a chip with a **capacity bar**
   `14/20h`) and **open roles across the community** (right, each posted by some WG project).
2. **Pick a person** → the roles they qualify for **light up**, each annotated with *their* spare
   capacity ("can give 6 of their 8 free hours"). **Pick a role** → qualified people light up,
   dimmed-with-reason if short on skill or hours.
3. Click the lit counterpart → an **inline confirm** pre-filled to the role's quota → **Assign**.
4. "Add directly" stops being a separate admin form: assigning a person to a project that has *no
   matching open role* simply **creates the role behind the scenes** (same gesture; the permission still
   gates it, the interaction is identical).
5. One RPC: `assign(person, role | newRole, hours)` wrapping today's `work_seat`/`seat_direct`.

**The WG officer never matches people** — they only **post roles** (declare demand) and **run** the
project. Supply and demand stay on opposite sides of the seam, which is exactly the org separation.

---

## 4. Six principles (the test for every screen)

1. **Two domains, never merged.** People-screens show people; Project-screens show projects. They meet
   only at the Role. If a screen mixes "my team" and "my projects," it's wrong.
2. **One concept = one word = one component = one gesture.** Kill the duplicate seating UIs, the two
   need-forms, the three badge paths.
3. **Direct manipulation over forms.** Matching is "put A on B" — a single gesture (§3), not a 6-step
   picker across a drawer.
4. **Progressive disclosure of the economy.** STR is accounting; surface it only at **Finish → Split**
   and on the personal **My** surface. Never lead an officer with "claimable STR."
5. **Make the constraint visible before it blocks.** Every person carries a **capacity bar**; you see
   the budget, then spend it — never a mystery-greyed Confirm.
6. **Trust + undo, not review-everything.** A steward's edits to their *own* unit apply immediately and
   reversibly. The queue is for acts that **cross the seam with value** (badges, settlement payout).

---

## 5. Interaction rebuilds, slotted into the two domains

### People surface (Chapter)
- **Roster:** each PersonChip = skills + a **capacity bar** (the one number an officer scans).
- **Add a person:** name · email · affiliation · **hours** · skills. Hours are a **person attribute**,
  not a `forge_resource` named "My time" — delete that modeling and the dead `saveLabor`/`addResource`.
- **Matching board:** the one Assign gesture (§3).
- **Skills/badges:** one `SkillTree` everywhere (read = filled pips, edit = clickable); awarding to
  someone = the same tree on their card. Kill `ForgeCard mode="badge"` and the Community award panel's
  separate path.

### Projects surface (Working Group)
- **Project worklist:** each ProjectCard = status + open-role count + **one stage-action**.
- **Create / claim** a project (free, no bond; first-author seat stays open).
- **Post a role:** one form (skill+level+hours, or a resource) — kill `ForgeCard mode="need"`, keep one.
- **Run:** the single `Pipeline` stepper; rename **Mint done → Finish**, **Settle → Split the credit**.
- **One object pattern:** peek = drawer, deep = route — never a drawer hosting a full tabbed body
  (kill the dual-body project rendering).

### My surface (personal / researcher) — quiet in P1, hero in P2
- My card, my contributions, my wallet. This is the "player" hat from the old player-coach idea —
  but it lives **here, on the person's own surface**, not as a lane bolted onto an officer console.

---

## 6. Vocabulary — final, enforced in nav · buttons · copy · admin · tooltips

| Drop (banned) | Use | Domain |
|---|---|---|
| slot / open_need / work_labor | **Role** | the seam |
| seat / bind / forge / seat_direct | **Assign** | People (matching) |
| "My time" resource / monthly_quota | **Hours / capacity** (person attribute) | People |
| nominal / liquid STR (as hero) | **Credit** (quiet); STR is the ledger unit | My / Finish |
| Mint done / settle / harvest | **Finish** → **Split the credit** | Projects |
| apprentice…master | **Beginner · Intermediate · Advanced · Expert** (DB keeps ranks; UI never shows old words) | People |
| Forge queue | **Review inbox** | Settings |
| Chapter / Working Group | keep — they are the two domains; make them the IA spine | — |

---

## 7. Review — three tiers (one inbox, in Settings)

| Tier | Acts | Mechanism |
|---|---|---|
| **Immediate + undo** | Chapter officer adds/edits own roster, sets hours, assigns within scope; WG officer posts a role / edits own project | applies now; Undo; no queue |
| **Light handshake** (crosses the seam) | a Chapter places a person onto **another WG's** project; a WG **claims** an unowned project | a notification the receiving steward accepts |
| **Value review** (admin) | badge grants (confer credit), settlement payout, capacity overrides | the queue stays **only** here |

Biggest ceremony cut: stewards stop asking permission to run their own domain.

---

## 8. Component cull

~**8** components, one each:
`PersonChip` (capacity bar) · `ProjectCard` (roles + stage action) · `RoleRow` · `AssignSheet`
(the single in-place confirm) · `SkillTree` · `ResourceForm` (rare: GPU/data/funding only) ·
`Pipeline` · `ReviewItem`.

Delete: the 2nd/3rd seating UIs, `ForgeCard` need+badge modes, the STR-ring-as-hero home, `StartHere`
(fold into empty-states), legacy `saveLabor`/`addResource`, and the **6 dead backend subsystems**
(token economy, apply→accept→confirm join, stake commitments, skillcards, skill-exam+endorsement,
resource offers, paid-leader bonds) via one legacy-purge migration.

---

## 9. Rollout — incremental, each step reversible

- **A — Language & dedup** (pure relabel + delete; zero data change): §6 vocabulary; collapse duplicate
  forms to single components. *Ship, observe.*
- **B — Split the console into the two domain surfaces** (People = roster + matching · Projects = WG
  worklist). Wire Home as the role-aware router. No new gesture yet — just the clean separation.
- **C — One matching gesture + visible capacity bar** (§3) behind one `assign()` wrapper.
- **D — Review tiering** (immediate + undo for own-domain acts; queue shrinks to value/cross-seam).
- **E — Cull** (legacy-purge migration · routes ~20→5 · hours-as-attribute).

End state: **People + Projects + My + Directory + Settings · ~8 components · one seam · one word per
concept · one gesture per act.**

---

## 10. Acceptance test

> A **Chapter** officer opens **People**, sees their roster with capacity bars and the open roles, drags
> a free person onto a fitting role — done, no economy words in sight. A **WG** officer opens
> **Projects**, sees their group's projects, posts a role, later clicks **Finish → Split**. Neither ever
> manages the other's domain, and neither meets *slot, forge, nominal, seat, or harvest*. If a screen
> shows a person their *own* projects next to their *team*, or one act needs two forms — it's pointed at
> the wrong structure, and must be split or removed.

---

## 11. HCI foundations & precedents (why each decision is not arbitrary)

*Each design choice above maps to a named principle and a product that solved the same problem. Canon
referenced: Norman, *The Design of Everyday Things* (affordances/signifiers, mapping, constraints,
feedback, conceptual model, gulfs of execution & evaluation); Nielsen's **10 Usability Heuristics**;
Shneiderman's **8 Golden Rules** + **Direct Manipulation** (Hutchins–Hollan–Norman, 1985); Pirolli &
Card, **Information Foraging** (information scent); **Fitts's** & **Hick's** Laws; Miller's **7±2**;
Krug, *Don't Make Me Think*; Cooper, *About Face* (goal-directed design, personas); Tidwell, *Designing
Interfaces* (UI patterns).*

| Decision (this doc) | HCI principle it rests on | Real-world precedent to borrow from |
|---|---|---|
| **§0–2 Bipartite People/Projects, never merged** | Norman **conceptual model** must mirror the user's mental model; Nielsen #2 **match system ↔ real world**; IA (Rosenfeld–Morville) — organize by the user's domains, not the DB schema | **GitHub** (People/Org vs Repos), **Linear** (Teams vs Projects), **Workday/HR** (People vs Work) all keep the two axes structurally apart |
| **§1 One Role = the single seam** | Reduce **modes**; one clean conceptual bridge between domains | **Two-sided marketplaces** — Upwork/ATS: demand (jobs) and supply (talent) meet at one listing object |
| **§3 One Assign gesture; select→fitting-counterparts-glow** | **Direct Manipulation** (continuous representation, reversible physical actions, immediate feedback) closes Norman's **gulf of execution**; **Information scent** (Pirolli–Card); Nielsen #6 **recognition over recall**; Norman **constraints** (only valid targets are actionable) | Move-highlighting in **chess/lichess**; **Trello/kanban** drag; **Google Calendar** "find a time"; IDE autocomplete narrowing valid options. *Click-to-highlight beats pure drag — see caveat below.* |
| **§3.2 Capacity bar visible before it blocks** | Nielsen #1 **visibility of system status**; Norman **forcing functions / visible constraints**; Nielsen #5 **prevent errors** > #9 good error messages | **Float / Resource Guru / Harvest** (utilization bars), airline **seat maps**, Calendar busy-bars — you see the budget before you spend |
| **§4.4 Progressive disclosure of STR** | **Progressive disclosure** (Nielsen/Tidwell); Nielsen #8 **aesthetic & minimalist**; defer complexity | **Stripe** (complex money, calm surface); **Stack Overflow** rep is visible but never the workspace; banking apps hide the ledger behind the task |
| **§7 Trust + undo, not review-everything** | Nielsen #3 **user control & freedom (undo)**; Shneiderman rule #6 **reversible actions**; cut ceremony | **Gmail "Undo Send"**, **Linear/Notion** optimistic edits + undo, Google Docs — vs heavyweight SAP-style approval chains users route around |
| **§6 One word per concept** | Nielsen #4 **consistency & standards**; Nielsen #2 **users' language**; Krug **"don't make me think"** | **Apple HIG** terminology discipline; the whole anti-jargon canon |
| **§5 One object pattern (card → drawer peek → route deep)** | Nielsen #4 consistency; spatial memory; **master–detail** pattern (Tidwell) | **Gmail / Linear / Superhuman** list→peek→full; macOS Finder |
| **§2 Role-aware Home router; ~20→5 surfaces; 6 nouns** | **Hick's Law** (fewer top-level choices = faster decisions); **Miller 7±2** (6 nouns ≈ one chunk); Cooper **goal-directed** role dashboards | **Salesforce / GitHub** role-contextual homes |
| **Card shells, glow, grouping** | **Gestalt** (proximity, similarity, common region); **Fitts's Law** (big click targets, short travel) | Card UIs everywhere — Trello, Linear, Notion |

### Where precedent should actually *change* the design (honest caveats)
- **Don't ship pure drag-and-drop matching.** Drag is a *hidden* affordance (Norman **signifiers** problem) — poor discoverability, weak accessibility, awkward on touch. Float/Trello all provide click-equivalents. So §3's primary gesture is **select → valid targets glow → click**, with drag as an optional accelerator, not the only path.
- **Capacity is time-phased, not a single number.** Resource-management tools (Float, Resource Guru) learned that "free hours" must be shown **per period** (this week / this month), because a person free in March is busy in April. The capacity bar should carry a month/period context, not one lifetime figure.
- **A matching board tends to rot into a spreadsheet.** The failure mode of allocation tools is a dense grid no one reads. Keep it **card-based with strong scent** (glow, capacity bars, dim-with-reason) — closer to a kanban than to Excel.
- **Two-sided markets need the demand side to feel the supply.** Upwork/ATS show posters how many qualified candidates exist. A WG officer posting a Role should see *"~4 people across chapters could fill this"* — otherwise demand is posted blind.

### Honest gap
v1/v2's body applied these heuristics **implicitly** and cited **none**. This section is the missing
grounding. Two things still need real-world validation rather than authority: (1) the **player-coach →
two-domain-officer** split is reasoned from the org chart, not from observing the actual officers — it
should be checked against how a real chapter secretary vs WG lead actually works; (2) the
**select-glow-assign** gesture should be **usability-tested** with one officer before we commit Phase C.

---

## 12. Deeper friction — what still blocks *understanding* and *operation*

*§0–11 fixed **structure** (two domains) and **gesture** (one assign). But a user can sit on a perfectly
organized screen and still be lost. The remaining blockers are not layout — they are about the four
things a person needs to act with confidence: a **mental model**, a sense of **time**, **feedback on
what happened**, and a model that **matches how collaboration actually works**. Each below is written in
the user's voice, then answered with a concrete design move.*

### The root friction (name it plainly)
> *"I'm being asked to run a **token economy** I don't understand, on behalf of **people who never
> agreed to it**."*

That sentence is under everything else. Two consequences shape the whole layer: the **economy is a black
box** (A) and the **person is treated as inventory** (E). Fixing the surface won't help until these do.

---

### A. Conceptual-model blockers — *the user can't form a correct picture*

**A1 — STR is an unexplained black box.** *"Hours turn into… credit? nominal vs liquid? worth what?"*
Hiding STR (§4.4) is not the same as making it understood; the moment it surfaces at Finish→Split, the
officer faces a weighting form with **zero grounding**.
→ **Design:** never require understanding STR to *operate*; show it only as **"credit ≈ N"** derived
live, with a one-tap **"how is this computed"** that states it in the user's units (*hours × rate*).
Rename **nominal/liquid → accruing/paid**. Put **one worked example** on the Wallet ("12h writing this
month → ≈ 120 credit, paid when the paper settles"). Principle: Norman **conceptual model** made visible;
Nielsen #2.

**A2 — Skill levels are unanchored.** *"'Advanced Writing' by whose standard? who decided? can I trust
it?"* A badge is granted but the **rubric and provenance are invisible**, so neither the rater nor the
filler trusts the level the whole match depends on.
→ **Design:** every level carries a **one-line rubric** on hover ("Advanced = has led a paper's
writing") and a **provenance chip** (*certified by Li · 2026-03* vs *self-claimed · pending*).
Self-claimed and certified must **look different**. Without provenance the matching premise is hollow.

**A3 — Valuation is a hidden rate.** *"I'm offering a GPU / 200h — worth how much credit? no idea."*
GPU-hours, 1M-tokens, USD, hours all convert to STR by rates the user never sees.
→ **Design:** **live valuation preview** the instant a resource or role is declared ("200 GPU-h/mo ≈ N
credit/mo"). Legible rate, not a black box. Same preview when a WG posts a role.

### B. Temporal-model blockers — *the user can't reason about time*

**B1 — Commitments have no visible duration or renewal.** *"20h/month — for how many months? does it
renew? when is Zhang free again?"* Commitments are stored per `year_month` but the UI shows an
open-ended "20h" with **no start, end, or horizon**. This is the biggest hidden-state trap.
→ **Design:** an assignment shows **a window** (from–until / "ongoing, renews monthly") and the roster
carries a tiny **per-period capacity** (this month / next month toggle), because someone free in March is
busy in April. Precedent: Float / Resource Guru learned capacity must be **time-phased**, never one
lifetime number.

**B2 — Deadlines and commitments are disconnected.** A project has a venue deadline; a person has a
monthly commitment; nothing links them. *"Will this role even be staffed in time?"*
→ **Design:** show a role's **demand against its deadline** ("needs 2 writers, deadline in 18 days,
0 filled") so urgency is visible where the decision is made.

### C. Feedback & state blockers — *the user can't tell what happened or what's next*

**C1 — Acting into a void.** *"I assigned Zhang. Did anything happen? Does he know? Did the WG see it?"*
The act returns to a reloaded list with **no consequence shown**.
→ **Design:** after every act, show the **consequence inline**: "Zhang now 18/20h · role 2/2 filled · WG
lead notified." Plus a real notification to the assignee. Nielsen #1 at the **workflow** level.

**C2 — No "what needs me."** A user logs in and must **hunt across surfaces** to find what's pending,
blocked, or waiting on them. There is no inbox-zero.
→ **Design:** Home leads with a **"your turn" list**, role-scoped: *Chapter* — "3 new roles your people
fit · 1 person just freed up · 2 awaiting review"; *WG* — "your project finished → split credit · a role
you posted got filled → confirm." The dashboard becomes a **triage queue**, not a wall of stats.

**C3 — Pending/blocked states are scattered and silent.** Approval, capacity-review, claimed-but-not-
confirmed all live in different places with no unified signal.
→ **Design:** one **status vocabulary** surfaced as consistent badges + a personal **activity trail**
("things I did") so state is recognizable, not recalled.

### D. Decision-support blockers — *the user can't make a good choice*

**D1 — An open role gives no context to place against.** *"'Writing Advanced ×2' — but what's the
project, who's already on it, what's the deadline, is it a fit?"* The filler decides **blind**.
→ **Design:** the RoleRow expands into a **decision card**: project one-liner · deadline · who's already
seated · the actual monthly commitment. Strong **information scent** (Pirolli–Card) where the choice is made.

**D2 — "Qualified" explains nothing.** A fitting person just **glows**; the officer doesn't see *why*.
→ **Design:** show the **positive reason**, not only the blocking one: "Advanced Writing ✓ · 6h free ·
on 2 similar projects." Make the match legible, so the officer trusts it.

**D3 — No triage among many roles → decision paralysis.** Everything looks equally urgent (Hick's Law at
the data level).
→ **Design:** rank/flag roles by **urgency** (deadline, headcount gap) and surface "most urgent
unfilled" first. Give demand a **priority signal**.

**D4 — Demand is posted blind.** A WG officer posts a role with no idea whether anyone can fill it.
→ **Design:** at post time, show the **candidate-pool size** ("~4 people across chapters qualify").
Two-sided markets must let the demand side feel the supply (Upwork/ATS).

### E. Social-model blockers — *the model misrepresents collaboration*

**E1 — People as inventory; assignment without consent.** The Chapter officer **moves a person onto
work like a token**. Even as a P1 proxy, the model has **no notion of the researcher agreeing**.
→ **Design:** model an assignment as a **proposal with a state** — *proposed → active*. In P1 the
officer confirms on the person's behalf, but the state exists, the assignee is **notified**, and P2 turns
it into a real accept/decline. Removes the "silent conscription" feel; future-proofs the social contract.

**E2 — No negotiation / decline / re-fit.** Real staffing is a conversation; the UI only allows
top-down placement.
→ **Design:** a lightweight **decline-with-reason** and **re-propose** path (P1: officer records it; P2:
the person does). The seam becomes a handshake, not a push.

**E3 — The highest-stakes moment is the least-supported.** **Credit split** decides real reward, yet the
officer does it in a **bare weights form** with no record of who actually did what.
→ **Design:** default each contributor's weight to **their logged hours over the project's life**, show
a **fairness summary** (shares sum to 100%; flag "big contributor, tiny share"), and surface the
**contribution history** beside the form. Make the moment that matters most the best-supported one.

**E4 — No notification spine.** Everything is **pull** (go look). Async coordination across people is
impossible without push.
→ **Design:** an in-app **notification inbox** (+ optional email) for the events above: a fillable role
opened, you were proposed to a role, your settlement was approved.

---

### What this re-orders in the rollout
Several of these block comprehension **more** than the matching-gesture polish does. **Legibility should
precede gesture.** Revised priority inside the staged plan:

1. **A + C2 first** (make the economy legible; give the user a "what needs me" home) — the cheapest, highest-trust wins, mostly copy + a derived value + one list.
2. **D1–D2 + B1** (decision context on roles; time-phased capacity) — these make the *one gesture* actually usable; do them **with**, not after, Phase C.
3. **E1 + E4** (proposal-state + notifications) — the social spine; unlocks Phase 2 and removes the conscription feel.
4. **E3** (supported credit split) — before the first real settlement happens, not after.

The acceptance test (§10) gains a clause: *the officer can answer, without asking anyone — "what is this
credit worth, when is this person free, what happened after I acted, and does the researcher know?"* If
not, the screen is still a black box, however well-organized.
