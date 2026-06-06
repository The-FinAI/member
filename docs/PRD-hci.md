# The Fin AI Community — HCI-First PRD

*Status: draft for the redesign. This document is the source of truth for **what the
product is, who it serves, and how interaction must work**. It supersedes ad-hoc
component decisions. HCI is the core constraint, not an afterthought.*

---

## 0. Why this doc exists

The app grew by **accretion** — every request added a page or a component, almost
nothing was removed. The result (measured, today):

- **41 routes, ~40 components.** `/admin/*` alone has **22 routes**, most superseded by
  the 5 admin consoles. `/officer/chapter`, `/officer/wg`, `/opportunities` are
  dead/duplicate. Legacy components: `Matcher`, `SlotBoard`, `CardBinder`, `MemberCard`,
  `GettingStarted`.
- The same data (STR, projects) is restated in 4 skins; the home alone stacked 3 heroes.
- Interaction paradigms are mixed (drawer vs route vs inline-toggle vs tabs) so a click is
  **unpredictable**.
- Surfaces mirror the **database** (units, slots, forge_requests) instead of the user's
  **job** (turn people's research work into settled STR).

The fix is not more components. It is **editorial consolidation + one coherent interaction
system**, designed against explicit HCI laws.

---

## 1. What the product is

A platform that turns **research collaboration** into a **settled token (STR) economy**.
The single object is the **project**; the single process is the **loop**:

```
recruit people → they contribute (hours/resources/milestones) → project finishes → settle → STR paid out
```

Everything in the UI should serve seeing the **state** of that loop and taking the **next
action** in it.

## 2. Users & phases

| | Phase 1 (now — custodial) | Phase 2 (later — open) |
|---|---|---|
| **Members** | exist only as **cards** (cannot log in). Their work is recorded *on their behalf*. | log in, claim their card, act for themselves. |
| **Officers** | the **only** logged-in operators. Chapter officers steward *people*; WG officers steward *projects*. | become coordinators, not proxies. |
| **Admins** | govern the economy + **approve** the review queue. | same. |

Design implication: phase 1 must be an **operator cockpit** ("you operate N people"),
phase 2 a **member dashboard**. Build the cockpit so the member view is a *mode*, not a
rewrite.

## 3. Jobs-to-be-done (what each role is actually trying to do)

- **Chapter officer:** *"Get my people onto projects so their work turns into STR."*
  → add people (skills + monthly hours) · match them to open needs · keep them deployed.
- **WG officer:** *"Run my projects to completion and pay people out."*
  → create/claim projects · post needs · seat people · drive milestones · **settle**.
- **Admin:** *"Keep the contribution graph honest and the economy configured."*
  → approve forges · set rates/policy/taxonomy.
- **Member (P2):** *"See my contribution and STR; do my own work."*

If a screen doesn't advance one of these jobs, it shouldn't be primary.

---

## 4. HCI principles (the laws this product commits to)

1. **One home, one truth.** Each concept (STR, a project's state) has **one** authoritative
   display. No restating the same data in competing widgets.
2. **Task-first, not entity-first.** Organize around the loop + next action, not around
   tables to browse. Surface *"what needs you"*.
3. **One card system.** Every entity wears the **same anatomy**: identity · status signal ·
   one key metric · one primary action. No bespoke card per surface.
4. **One interaction rule.** A card-click opens its **focused detail** (drawer on wide,
   page on narrow). Inline actions are **explicit buttons**, never text that secretly
   toggles. Predictability over cleverness.
5. **Cause next to effect.** The result of an action appears **where you act** (inline),
   not in a bar somewhere else.
6. **Visible system status + narration.** The UI says what state you're in and what to do
   next ("Filling X — seat a candidate").
7. **Progressive disclosure + rhythm.** Each surface: one hero (the answer) → support →
   deep edit on demand. Consistent spacing/type scale.
8. **Plain domain language.** Research words (collaborator, project, contribution, settle),
   not schema words (slot, forge_request) or crypto words (miner, hashrate). Keep `STR`,
   `nominal`, `liquid`.
9. **Minimize choices (Hick's law).** Offer the one next-best action, not a wall of equal
   options.
10. **Recoverable + safe.** Confirm irreversible acts; gate by permission/capacity *before*
    the click (disable + reason), not by error after.

---

## 5. Information architecture (target)

Four **primary** surfaces (role-filtered) + a thin secondary group.

```
Home        — the cockpit: your STR, loop status, and the ONE next action.
Projects    — the work & the STR engine. Browse · create · a project (team/needs/pipeline/settle).
Console     — (officers) the matching workbench: your people ⟷ open needs, seat in place.
Wallet      — your STR (liquid + nominal) + "how you earn STR".
— secondary —
Community   — directory of people & units (reference).
Admin       — review queue + economy/taxonomy config (admins).
Guide       — help (a link, not a workspace).
```

This is the spine. Member cards, unit pages, the skill tree, card creation, the review
queue are **reachable** surfaces, not nav-level destinations.

---

## 6. The interaction system (the part that's currently a soup)

### 6.1 The Card (one component, everywhere)
Anatomy, fixed:
`[type tag] [status pill]` / `Title` / `subtitle` / `[one key metric] [one primary action]`.
- The **status pill** is meaningful and colored (Open · Recruiting · Ready to settle · Full).
- The **metric** is the single number that matters for that entity (project: pool/your
  contribution; person: hours free/total; need: candidates qualified).
- The **primary action** is on the card (Seat · Post need · Settle), not buried.
- A click on the body opens the **detail**; the action button does the action **in place**.

→ Merge `EntityCard`, the cockpit cards, `ProjectSlotCard`, `MemberCard` into ONE.

### 6.2 The Detail (one rule)
- Wide viewport: a **drawer** (focused peek, keep list context).
- Narrow viewport: the **route page** (`/projects/[id]`, `/members/[id]`).
- The drawer shows **read + the single most relevant action**. Deep multi-section editing
  is the route page. **No drawer-opens-drawer. No sprawling tab apps in a drawer.**

### 6.3 Actions
- **In-place**: routine actions (seat, post need, approve) complete **inline / in a focused
  action sheet** and return you to where you were.
- **Explicit affordances**: buttons look like buttons. Kill the "looks-like-text toggle"
  pattern (post-need / add-directly).

### 6.4 States (every list & form must define)
- **Empty** (first-run): one sentence + the one action to start.
- **Loading**: skeletons, not spinners-on-blank.
- **Blocked**: disabled + the reason inline (we have capacity/permission gating — keep).
- **Done**: confirmation + what changed.

### 6.5 Forms
- One field group at a time, labels above, validation inline & pre-emptive.
- Type-adaptive (we did this for resources) but never reveal irrelevant fields.

---

## 7. Component library (canonical set)

Keep & standardize: **Card**, **Drawer**, **ActionSheet**, **StatusPill**, **Stepper**
(pipeline/onboarding), **SkillTree picker**, **ResourceForm** (have it), **ReviewItem**,
**Cockpit**.

Kill / merge (dead or duplicated today): `Matcher` (→ MatchConsole), `SlotBoard` (dead),
`CardBinder`, `MemberCard` (→ Card), `GettingStarted` (P2-only, fold into cockpit empty
state), `ForgeCard` need-mode (→ ResourceForm need-mode, already done).

---

## 8. Surface-by-surface spec (current problem → target)

### 8.1 Home / Cockpit  ✅ partly done
- **Problem:** was 3 stacked heroes restating STR/projects.
- **Target:** identity header + **one cockpit** — a focal ring (claimable vs accruing), a
  one-line status, the **single next action** (Settle / Assign collaborators / Find a
  project), then *your projects* and *your team*. Member-mode = the same shell, member data.

### 8.2 Projects (list + detail)
- **List:** the standard Card grid. Status pill = lifecycle stage; metric = open needs or
  pool; action = Open / (officer) Post need.
- **Detail (`ProjectDetailBody`):** **Problem** — a drawer stuffed with pipeline +
  post-need + seater + tabbed card-body + settlement; click behavior inconsistent.
  **Target:** top = the **STR pipeline** (have it) as the spine; one **primary action by
  stage** (Recruiting→Post need / Finished→Settle); team & needs as a clean list with
  **inline seat**; deep edits (links, meetings, history) on the route page, not the drawer.

### 8.3 Console (matching)  ✅ reworked
- **Problem:** bidirectional pick-need+pick-person, seat bar disconnected at top.
- **Target (shipped):** a **directional guide line** narrates state; selecting a need
  highlights candidates and each shows an inline **Seat →** that expands amount/confirm in
  the row. Extend the same inline pattern to the WG side. Move "create project / add
  member / post need" into a single **＋ New** menu so the board is just matching.

### 8.4 Community + Member card
- **Community:** a **directory** (people / chapters / working groups) — reference, not a
  workbench. Standard Cards, filter/search.
- **Member card (`MemberDetail`):** **Problem** — tabbed mini-app (overview/badges/
  projects/resources) with mixed editors. **Target:** identity header → contribution
  snapshot → **Resources** (the unified ResourceForm, with edit) → **Skills/Badges** →
  Projects. One scroll with anchored sections, not a tab maze. Editing = inline field +
  the ResourceForm; review-gated (done).

### 8.5 Wallet  ✅ earn-loop added
- Keep: balance hero + **"how you earn STR"** loop + ledger. This is the *one* place STR
  detail lives; the cockpit links here.

### 8.6 Admin — **the biggest sprawl**
- **Problem:** **22 routes**. The rebuild created 5 consoles (access, projects, guild,
  economy, announcements) but the old per-table routes were never deleted: `approvals`,
  `capabilities`, `invites`, `milestone-catalog`, `org-units`, `positions`,
  `resource-types`, `resources`, `roles`, `skills`, `statuses`, `types`, `venues`,
  `writing`, plus `review` / `forge-queue` overlap.
- **Target:** **Admin hub + exactly the 5 consoles + the review queue.** Each console owns
  its sub-tables internally. **Delete the ~15 legacy routes.** One approval surface (the
  forge/review queue), admin-only (done).

### 8.7 Skill tree & badges — **called out as a disaster**
- **Problem:** the skill economy is exposed across `SkillTreePanel`, `SkillLevelPicker`,
  `BadgeTree`, `Medal`, `/admin/skills`, `/admin/guild`, the public skill tree — different
  shapes for "pick a skill at a level". Picking levels (4 ranks × N leaf skills) is dense
  and inconsistent between admin and member.
- **Target:** **one SkillTree picker component** (leaf skills grouped by domain, 4 rank
  pips, one interaction) used **everywhere** a skill+level is chosen: badge claim, member
  forge, labour need, resource skills, admin defaults. Read-only display = the same tree,
  pips filled. Kill the divergent variants. Certification flow: stage on the tree → submit
  → one review batch (we fixed the 10-approvals bug; keep batch).

### 8.8 Card creation (建卡) — **called out**
- **Problem:** forging a member starts an identity-only form, then you reopen the card to
  add skills/hours/resources — multi-trip, and it lived behind jargon.
- **Target:** **one create flow, one screen:** identity → skills+levels (SkillTree) →
  monthly hours → (optional) a first resource, submitted as **one batch** (we wired
  badges+hours; finish the resource step). Plain label: **"Add a member"**. After submit,
  a clear "what happens next" (goes to review; they claim by email in P2).

### 8.9 Review / forge queue  ✅ admin-only + detail
- Keep: one queue, admin-only, each item shows its **specific content** (skills+levels,
  quota, description) and groups batches. This is the single approval surface.

### 8.10 Login  ✅
- Invite-only OTP; unclaimed cards blocked in P1. Keep; clarify copy.

---

## 9. Route & component consolidation (concrete cleanup)

**Delete (legacy/dead):** `/opportunities`, `/officer/chapter/[unitId]`,
`/officer/wg/[unitId]`, and the admin legacy set (`approvals`, `capabilities`, `invites`,
`milestone-catalog`, `org-units`, `positions`, `resource-types`, `resources`, `roles`,
`skills`, `statuses`, `types`, `venues`, `writing`) — fold each into its owning console.

**Components to retire:** `Matcher`, `SlotBoard`, `CardBinder`, `MemberCard`,
`GettingStarted` (P2), `ForgeCard` (need-mode).

Target: **~12 routes, ~20 components.** (from 41 / ~40.)

---

## 10. Remediation roadmap (phased, HCI-leverage order)

1. **Home cockpit** — done.
2. **Console matching** interaction — done.
3. **One Card + one Detail rule** — refactor `EntityCard` to the canonical anatomy; apply
   to Projects, Community, cockpit. Drawer = peek + 1 action; deep edit on route page.
4. **Skill tree unification** — one picker everywhere; kill variants.
5. **Card creation** one-screen flow.
6. **Project detail** = pipeline spine + stage action + inline seat; move deep edits to page.
7. **Admin consolidation** — delete the ~15 legacy routes; 5 consoles + queue only.
8. **Member card** de-tab.
9. **Route/component cull** + jargon final pass.

Each step is **removal/unification**, not addition.

---

## 11. Success metrics (HCI)

- **Time-to-first-action** for a new officer (login → first person seated) ↓.
- **Clicks-per-task** for the core loop (recruit, seat, settle) ↓.
- **Error/confusion rate**: failed seats, "where is X" support questions ↓.
- **Surface count**: routes 41→~12, components ~40→~20.
- **Self-serve onboarding**: officers complete the loop without asking.

---

---

## 12. Definitions & taxonomy — the HCI audit of the **content/config layer**

Interaction polish can't fix a model that doesn't match how researchers think. The
*definitions* (terms, ranks, skill tree, positions, permissions, statuses) are themselves
a usability surface — judged by **match-to-real-world**, **recognition**, **consistency**,
**plain language**. Current state vs target:

### 12.1 Skill ranks (the level ladder)
- **Now:** `Apprentice → Journeyman → Craftsman → Master` (a medieval **guild** metaphor;
  "guild ladder", "Guild & skills"). Researchers must translate every time.
- **Target:** plain proficiency — **Beginner → Intermediate → Advanced → Expert** (4 kept).
  Drop the word **"guild"** entirely → "Skills". Pips/medals stay; only the labels change.
- *(DB: keep the `guild_level` enum values to avoid a migration storm; rename only the
  human labels in i18n + a display map. The enum is internal.)*

### 12.2 Skill tree taxonomy
- **Now:** the top level literally contains a node named **"Domain"**; structure is uneven
  (Engineering, Language, Domain[=finance subfields], plus loose research skills).
- **Target — research-grounded domains**, named the way a Fin-AI researcher self-describes:
  1. **Research & Writing** — Paper Writing, Literature Review, Experiment Design, Benchmark
     Design, Evaluation & Metrics.
  2. **Engineering** — Data Pipelines, Distributed Training / GPU, Inference & Serving,
     Frontend / Backend.
  3. **Finance domain** — (the current finance subfields: Equities/Trading, Risk, Audit/XBRL,
     Portfolio, Banking/Credit, RegTech, Macro, ESG). Rename the node "Domain" → **"Finance"**.
  4. **Languages** — for multilingual annotation/eval.
  5. **Coordination** — Mentoring/Onboarding, Outreach, Facilitation, Organization.
- One **SkillTree** component renders this everywhere (§8.7). Domains must be **mutually
  legible** (a person knows which bucket their skill is in in <2s).

### 12.3 Positions / roles — **two parallel systems, collapse them**
- **Now:** a corporate `position` ladder (`President · Board · Steering · Executive Chair ·
  Executive · Researcher`) **and** a separate `org_unit_officer` role (`chair · secretary ·
  leader`). Two ways to say "who someone is" → confusion, and the board layers aren't used.
- **Target — one small, legible role set:**
  - **President** (org owner) — global authority.
  - **Officer** — *of a unit*, with a unit role: **Chapter Chair / Chapter Secretary** (steward
    people) or **Group Lead** (steward projects). This is the real operating role in P1.
  - **Researcher** — a member (P2: logs in).
  - Drop `Board / Steering / Executive Chair / Executive` unless a real governance need
    exists; they're unused ladder cruft.

### 12.4 Capabilities → **human permission groups**
- **Now:** raw technical keys shown to admins: `manage_stater, mint_skillcard,
  review_skillcard, manage_members, invite_members, edit_any_project, manage_guild,
  manage_taxonomy, manage_resources, manage_tokens`.
- **Target:** keep the keys *internal*; in the Permissions UI show **named groups**:

  | Group (UI) | wraps |
  |---|---|
  | **Approve credentials** | review_skillcard, mint_skillcard |
  | **Manage people & access** | manage_members, invite_members |
  | **Manage projects** | edit_any_project |
  | **Manage skills & catalog** | manage_guild, manage_taxonomy |
  | **Manage resources** | manage_resources |
  | **Run the STR economy** | manage_stater, manage_tokens |

  An officer's position grants groups, not cryptic keys. (Recognition over recall.)

### 12.5 Project statuses (lifecycle)
- **Now:** `Proposal · Data Collecting · Work in progress · Under review · Finished · Hold`.
  "Data Collecting" is over-specific (not all research collects data) and splits "active".
- **Target — clean lifecycle that drives the pipeline (§8.2):**
  **Proposed → Active → Under review → Finished** (+ **On hold**). Merge *Data Collecting*
  + *Work in progress* → **Active**. The status set IS the pipeline; one vocabulary.

### 12.6 Resource types
- **Now:** Compute/GPU · API Credits · Funding/Budget · Dataset/Data Access · Annotation
  Labor · Software/License · Expert Time · **Labor** · Other. Three "hours" types (Labor,
  Expert Time, Annotation Labor) overlap.
- **Target:** group by *what it is*: **People-time** (one type, with the skill/level on the
  resource — collapses Labor/Expert Time/Annotation), **Compute**, **API**, **Data**,
  **Funding**, **Software**, **Other**. Fewer, cleaner buckets; pricing still per type.

### 12.7 Core glossary (the canonical word for each concept)

| Concept | Use (EN) | 中文 | Banned (old/jargon) |
|---|---|---|---|
| the token | **STR** | STR | — |
| earned, locked | **nominal STR** | 名义 STR | (keep) |
| earned, spendable | **liquid STR** | 流动 STR | (keep) |
| create something | **Add / Create** | 添加 / 创建 | Forge, mint |
| an open role on a project | **Need / Seat** | 需求 / 席位 | slot |
| put a person on a need | **Seat** | 安排入座 | bind, commit |
| pay out a finished project | **Settle** | 结算 | harvest |
| skill level | **Beginner…Expert** | 初级…专家 | Apprentice…Master, guild |
| a person's record | **card** (P1) / member | 卡片 / 成员 | — |
| approval list | **Review queue** | 审核队列 | Forge queue |
| a lab/group | **Chapter** | 分会 | — |
| a project team | **Group** (working group) | 工作组 | WG (spell out) |

*Rule: one word per concept, used identically in nav, buttons, copy, and admin labels.*

### 12.8 Migration discipline
Most of this is **labels, not schema**: change i18n + display maps + seed *names*; keep
enum values & keys internal so we don't churn the DB. Only §12.5 (merge two statuses) and
§12.6 (collapse hours types) touch seed rows — do those as small, reversible data
migrations.

---

*Principle to hold the line: every change must **remove or unify**. If a proposal adds a
surface or a component, it must delete one too.*
