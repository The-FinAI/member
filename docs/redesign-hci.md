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

---

## 13. Micro-interaction logic — the mechanics of each moment

*§12 was about what the user must **know**. This is one layer below: the **mechanics of operating a
control** — modes, feedback timing, reversibility, view-state, keyboard, repetition. These are the
densest HCI debts in the as-is map, and they decide whether a structurally-correct screen actually feels
usable. New canon here: **Tesler's Law of modes** ("don't mode me in"); **Raskin** (modelessness,
monotony, "the interface should not have modes"); the **Doherty threshold** (<400 ms feedback keeps
attention); **gulf of evaluation** (Norman); **Tognazzini's** First Principles (anticipation, latency,
state-not-mode).*

### A. Modes — the matching board is a moded interface, and modes leak

The console holds **`selNeed` / `selPerson`** — that is a **mode**. The as-is mechanics betray every
classic mode failure: clicking a second person **silently swaps** the selection (no signal you lost the
first), there is **no Esc to exit**, and nothing persistently says *"you are placing Zhang."*
- **A1 — Mode visibility.** *"Wait, am I picking a person or a role right now?"* → A persistent
  **mode banner** ("Placing **Zhang** — pick a role · Esc to stop"), already half-built as `.mc-guide`;
  make it the **anchor**, sticky, with the active object named and an explicit exit. (Tesler: if a mode
  must exist, make it loud and escapable.)
- **A2 — Conflicting selection.** Clicking another candidate mid-place should **not** silently discard
  intent — either it's a deliberate re-pick (fine, but echo it) or guard it. **Monotony** (Raskin): one
  action, one result; no silent reinterpretation.
- **A3 — Escape & dismissal everywhere.** Esc cancels the current mode/sheet/drawer; click-outside
  dismisses; both restore the prior state. Today there is no keyboard exit at all.

### B. The reload-everything doom loop — the single biggest interaction-logic flaw

**Every** handler in the as-is map ends in `load()` / `loadGrid()` / `loadCatalog()` — a **full
refetch** that **discards scroll position, the open picker, the current selection, and any typed
input**. After seating one person, the officer is **thrown back to the top of the list** and must
re-find their place. For a repeat operator this is the dominant friction.
- **B1 — Optimistic, targeted updates.** The assigned chip updates **in place** (capacity bar ticks to
  18/20, the filled role drops out) **without a full reload**; the network call reconciles in the
  background. Doherty threshold: the *visible* result is instant.
- **B2 — Preserve view-state across actions.** Scroll, the selected person, the open section all
  survive the act. The user never loses their place.
- **B3 — Stale state across the seam.** When a WG closes a role, the Chapter board still shows it until
  a manual reload. → invalidate the role optimistically (and, later, push). Don't let the two domains
  drift out of sync.

### C. Feedback timing — close the gulf of evaluation per-keystroke, not per-submit

As-is, forms **validate on submit** and dump a single `e.message` string at the **top of the form**;
the offending field isn't even highlighted.
- **C1 — Validate while typing / on blur, inline at the field.** Hours-over-capacity reddens the field
  **as you type** with "only 6h free," not on a failed submit. (The seat input already computes
  `over`/`under` — surface it continuously, at the field, not as a disabled button's side-effect.)
- **C2 — Live preview of consequence.** Typing 8 hours shows "→ Zhang 20/20, full" live; declaring a
  resource shows "≈ N credit/mo" live (ties to §A3). The user sees the result **before** committing.
- **C3 — Sub-400 ms acknowledgement** on every click — a state change, not a frozen button. Spinners
  are a last resort for real latency, not the default ack.

### D. Reversibility mechanics — design undo, and guard the irreversible

§7 said "trust + undo" but didn't specify the **mechanics**. The as-is map has a landmine:
**`removeResource` hard-deletes with no confirm and no undo.**
- **D1 — Undo as a toast with a timer.** Reversible acts (assign, post role, set hours) apply
  immediately and show **"Assigned Zhang · Undo"** for ~6 s. No modal. (Gmail Undo-Send.)
- **D2 — Confirm only the truly irreversible.** Hard delete, releasing a started commitment,
  rejecting a settlement → a **typed/explicit confirm** *or* convert to soft-delete + undo. Never a
  silent destructive click. (Nielsen #5 prevent errors > #9 explain them.)
- **D3 — Distinguish reversible-without-consequence from socially-committed.** Un-assigning before the
  person starts = clean undo; after they've logged hours = a **withdrawal with notice**, not a silent
  revert (ties to §E1 social state).

### E. The disabled-button dead-end — never silently disable

The as-is map is full of `disabled={busy || over || under || (resource && !resId)}`. A disabled primary
button is a **dead end**: the main signifier says "no" and rarely says "**why**" or "**how to fix**."
- **E1 — Prefer enabled-with-guidance.** Keep the button clickable; on click (or inline, live) state the
  single blocking reason **and the fix**: "Commit at least 2h to fill this role." The user learns the
  rule by trying, instead of staring at a grey button. (For genuinely impossible states, disable **with**
  an always-visible reason adjacent — never bare.)
- **E2 — One reason at a time, nearest the cause.** Not a list of all failures at the form top — the
  *next* thing to fix, at the field that causes it.

### F. Error recovery — preserve, translate, retry

On RPC failure the as-is shows raw `e.message` at the top and leaves the user to re-derive what to do.
- **F1 — Never lose input.** The form keeps everything typed on failure.
- **F2 — Translate + offer the next step.** "That person is already at capacity this month — reduce the
  hours or pick another role," with a **Retry**, not a Postgres error string.
- **F3 — Idempotency / double-submit.** Guard re-clicks and network retries so one intent ≠ two
  assignments (today only `disabled`-while-busy half-covers this).

### G. Flow efficiency for the repeat operator — design for the 20th assignment, not the 1st

An officer staffs **many** people in one sitting; the as-is forces a **mouse-only, one-at-a-time,
reload-between-each** loop. (Raskin **monotony**: make the frequent path the shortest.)
- **G1 — Keyboard path end-to-end.** Type-ahead in the candidate search (already a text box — add
  arrow-key navigation + Enter to pick), Enter to confirm, Esc to cancel, Tab order that follows the
  visual flow. The whole assign can be done without the mouse.
- **G2 — Smart defaults that anticipate.** Pre-fill hours to **min(person's free hours, role's need)** —
  the most likely value — so the common case is **zero typing** (Tognazzini: anticipation). Pre-select
  the person's matching resource (as today) but show why.
- **G3 — Batch where the work is batchy.** Badges already batch; **matching does not**. Allow selecting
  several roles a person fits (or several people for one role) and assigning in **one confirm** — with a
  per-line capacity check. Cuts the dominant repetitive loop.
- **G4 — Don't re-collapse after each act.** The picker stays open for the next assignment on the same
  person/role until explicitly closed (pairs with §B2).

### H. Affordance & scent at the control level — is it even clickable?

Cards-as-buttons, rows-that-toggle, pips-that-set — without **signifiers** the user can't tell what's
interactive, and drawer→link→drawer **pogo-sticking** (Information Foraging) loses their place.
- **H1 — Visible signifiers.** Interactive cards/rows get a consistent hover/affordance cue; static
  display blocks must look static. (Norman signifiers; Gestalt common-region for grouping.)
- **H2 — Stop the pogo-stick.** Opening a related entity from a drawer should **peek without losing the
  parent** (stack/breadcrumb), not bounce the user to a fresh page and orphan their task.
- **H3 — Stable layout under type-morphing.** The `ResourceForgeForm` swapping fields by type
  **shouldn't reflow** the whole form (jumpy = disorienting); reserve space, animate the change so the
  user tracks what appeared.

---

### How §13 lands in the build
None of these need new data — they are **interaction-layer** fixes. Two are near-universal refactors
worth doing as their own pass, because they touch every screen:
1. **Kill the reload-everything loop** (§B) — replace `load()`-after-each-action with optimistic +
   targeted update. Highest usability-per-effort of anything in this doc.
2. **Replace silent-disabled with enabled-or-explained** (§E) and **submit-time errors with
   live-inline** (§C) — a single validation-pattern change applied app-wide.

Acceptance test gains its final clause: *can the officer staff ten people, by keyboard, without losing
their place, without re-finding a single row, undoing any misstep in one tap, and never meeting a grey
button that won't say why?* That is the difference between "organized" and "usable."
