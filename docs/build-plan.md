# Build Plan — executing `PRD-final.md`

*The concrete, phased plan to build the system the PRD describes. Each phase ships independently, is
reversible, and ends with build + i18n + commit/push. Migrations are written here but **applied by the
user** (`supabase db push`) — direct prod DB writes are blocked for the agent. Reuses the existing STR
ledger & settlement; leaves behind the forge/slot/wallet-home sprawl.*

**Stack:** SvelteKit 2 · Svelte 5 runes · Supabase (Postgres + RPC) · adapter-static SPA · GitHub Pages.
**Cross-cutting law:** every new component must satisfy the 12 interaction DoD rules (PRD §5) — optimistic
updates (no reload-everything), live-inline validation, enabled-or-explained, keyboard path, toast-undo,
peek-not-pogo. These are not a later phase; they are the definition of "done" for each component below.

---

## Phase 0 — The living record (Projects surface + Task) · *the heartbeat*

**Goal:** a WG runs on the Project page instead of its Google Doc.

**Migration `0500_task_and_project_record.sql`**
- `task` — `{id, project_id fk, grp text null, name text, skill_id fk null (=work-type), owner_member_id fk null, state text default 'open' (open|doing|done; coverage groups may use confirmed|checking|potential), note text, sort int, created_at, updated_at}`.
- `project` — add `emoji text`, `code text` (e.g. `ml-Tagging`), `tag text` (modality/lang), `body text` (rich). Proposal/Arxiv/References already exist as `project_link` kinds — keep.
- RLS: read = any member; write = project leader / WG steward / admin (reuse `can_edit_project`).

**RPCs:** `task_add`, `task_set` (owner|state|name|note|skill|grp), `task_remove`, `task_reorder`,
`project_set_meta` (emoji|code|tag|body).

**Components:**
- `record/TaskBoard.svelte` — inline-editable `Task · Type · Owner · Status · Note`; add-row; cell-edit; owner picker; **optimistic**, no reload.
- `record/CoverageGroup.svelte` — a task `grp` rendered as a checklist (dimension × state × owner).
- Rework the Project page into the living record (board + coverage + links + body + team + status).

**Routes:** `/projects/[id]` = living record · `/projects` = WG/project cards (emoji·code·status·open-task count).

**Import:** *Dropped — WGs re-enter their record in-app (no doc parser).*

**Acceptance:** open a project, add/assign/restate tasks inline without losing place; the project list
shows emoji · code · open-task count.

---

## Phase 1 — My tasks · *the cross-project worklist*

**Goal:** a member opens **My** and sees every task they own, across all projects.

- **Query/RPC:** `my_tasks()` → tasks where `owner_member_id = me`, grouped by project, with state.
- **Component:** `my/MyTasks.svelte` (state lanes: Doing / Open / Done) + "what changed this week".
- **Route:** `/my` (the My surface shell; tasks tab first).
- **Acceptance:** every owned task appears; clicking one peeks the project (no pogo-stick).

*(Depends on Phase 0 `task`.)*

---

## Phase 2 — People + capacity + skills (redesigned) · *the roster*

**Goal:** the People surface — roster with capacity bars and behaviorally-anchored, evidence-backed skills.

**Migration `0510_people_skills_capacity.sql`**
- `person_skill` — `{person_id, skill_id, level text (learning|independent|lead)}`. **Drop** badge/cert
  tables from the read path.
- `person.monthly_hours int` — capacity as a **person attribute** (migrate existing "My time" labor
  resources → this column, then retire that modeling).
- **Evidence view** `person_skill_evidence` — per (person, skill): count tasks owned + distinct shipped
  projects (derived from `task` + project status). Read-only, computed.

**RPCs:** `person_skill_set(skill, level)`, `person_set_capacity(hours)`,
`skill_raise_suggestions(person)` (returns "owned N → suggest Independent").

**Components:**
- `people/Roster.svelte` — PersonChip with **time-phased capacity bar** (this month / next) + skill lines.
- `people/SkillRow.svelte` — pick tag + segmented **Learning/Independent/Lead** (one tap, no pips) +
  evidence (`4 tasks · 2 shipped`) + accept-suggestion.
- Rework Person card to show skills-as-evidence, capacity, projects.

**Routes:** `/people` (roster + directory) · `/members/[id]` (person card).

**Acceptance:** set a skill in one tap; level shows its evidence; capacity bar reflects committed hours;
no badge tree, no certification queue anywhere.

*(Depends on Phase 0 for evidence; Phase 4 will read capacity.)*

---

## Phase 3 — Form by matching (Need + the seam) · *logic #1*

**Goal:** resource a forming project — select→glow→click matching, capacity-gated, level-ranked.

**Migration `0520_need_and_membership.sql`**
- `need` — `{id, project_id, skill_id null, desired_level null, resource_type_id null, capacity num, headcount int, status open|filled}` (reframes `project_slot`/`open_need`).
- `membership` — `{person_id, project_id, role, monthly_hours, since}` (reframes `work_commitment`); the
  source of contribution.

**RPCs:**
- `need_post(project, skill|resource, desired_level, capacity, headcount)` → also returns **candidate-pool size**.
- `match_candidates(need)` → roster ranked by **level fit + evidence + free capacity**, each with the
  positive reason; under-level included, over-capacity excluded. **This is the default path — the
  ecosystem engine.**
- `assign(person, need|new_role, hours)` → wraps/replaces `work_seat`/`seat_direct`; capacity is the hard
  gate; creates `membership`. Serves **both** the matched assign (A) and the direct override (B).

**Two paths (A default, B override) — decided:** *A = matched assign* is primary, because the
skill/level/capacity matching is what makes this an **ecosystem** (surfaces who-can-do-what, creates
demand signals, lets people grow into levels, gives STR meaning). *B = name-and-go* is an always-available
**override**: a lead who already knows who they want types the person in and assigns directly (this is
§14's direct-owner path). The system **guides toward A, never forces it.**

**Components:**
- `match/MatchBoard.svelte` — path **A**, the **one gesture**: select person → fitting Needs glow (spare
  capacity + level + why) → click → inline confirm pre-filled to `min(free, need)` → Assign. Mirror for
  select-Need. Keyboard path; batch-assign; optimistic.
- `match/NeedRow.svelte` — decision card (project · deadline · who's on · candidate-pool size).
- `match/DirectAssign.svelte` — path **B**, the override: search a person by name → assign directly
  (capacity still the hard gate, but no level/skill ranking). Reachable from any Need.

**Routes:** matching lives on `/people` (Chapter steward); `/projects/[id]` shows its Needs + team.

**Acceptance:** post a Need (see pool size), assign by select→glow→click, capacity blocks with a stated
reason, low-level candidates still appear ranked lower.

*(Depends on Phases 0/2.)*

---

## Phase 4 — Contribution + Settle (STR, reused) · *logic close*

**Goal:** finished work settles into STR; contribution is legible on My/profile.

- **Reuse** the existing STR ledger + settlement RPCs; wire `membership.monthly_hours` → contribution →
  pool. `Finish` → `Split` view: weights **default to logged hours**, **fairness summary** (Σ=100%, flag
  big-contributor/tiny-share), authors/corresponding, submit → review → STR paid.
- **Components:** `settle/SplitForm.svelte` (rebuilt on the DoD); `my/Wallet.svelte` (accruing vs settled,
  one-tap "how computed"); contribution line on the person profile + projected pool on a forming project.
- **Vocabulary:** Mint done→**Finish**, settle/harvest→**Settle/Split**, nominal/liquid→**accruing/settled**.

**Acceptance:** finish a project, split by hours with the fairness check, STR lands; STR is visible only
on My/Settle/profile — absent on board/roster/home.

*(Depends on Phase 3 membership/hours; reuses ledger.)*

---

## Phase 5 — Social spine · *proposal state + notifications*

**Goal:** assignment is a notified proposal, not silent conscription; async coordination works.

**Migration `0530_proposal_and_notifications.sql`**
- `membership.state` (`proposed|active`); `assign()` sets `proposed` + notifies the assignee.
- `notification` — `{recipient, kind, payload, read_at}`.

**RPCs:** `notify(...)`, `notifications_unread()`, `notification_read`, `proposal_accept|decline` (P1:
steward confirms on behalf; P2: the member).

**Components:** `shell/NotificationInbox.svelte`; consequence-echo on every act (Phase-wide retrofit:
"X now 18/20 · role filled · WG notified").

**Acceptance:** assigning notifies; a notification inbox shows what needs the user; proposal state visible.

---

## Phase 6 — Settings · *one console replaces ~15 admin routes*

**Goal:** collapse the admin sprawl into one Settings surface.

- **Catalogs:** the shared **skill list**, project types, milestone types, units & stewards.
- **Economy:** STR rates, **settlement review** (the one real value-review inbox), credential approvals.
- **Components:** `settings/` tabbed shell reusing existing admin panels; retire the rest.
- **Routes:** `/settings/*`; delete legacy `/admin/*` routes as each tab lands.

**Acceptance:** every governance task reachable from `/settings`; old admin routes gone.

---

## Phase 7 — Cull + the two app-wide interaction refactors · *finish the rebuild*

1. **Legacy-purge migration `0540_purge.sql`** — drop the 6 dead subsystems (token economy remnants,
   apply→accept→confirm join, stake commitments, skillcards, skill-exam+endorsement, resource offers,
   paid-leader bonds) and the orphaned `slot/forge` tables once Needs/Tasks fully replace them.
2. **Kill reload-everything** — replace every `load()`-after-action with optimistic + targeted update
   (app-wide pass). *Highest usability-per-effort.*
3. **Enabled-or-explained + live-inline validation** — one validation pattern applied to every form.
4. **Vocabulary sweep** — i18n pass enforcing PRD §6 (and zh clean); remove banned terms.
5. **Route reduction** — to the 5 surfaces (Projects · People · My · Directory · Settings) + Home router.

**Acceptance:** the PRD §8 acceptance test passes end-to-end; ~5 routes, ~8 components, 6 nouns.

---

## Dependencies & sequencing

```
P0 (Task/record) ─┬─▶ P1 (My tasks)
                  ├─▶ P2 (People/skills/evidence) ─▶ P3 (Need/match) ─▶ P4 (Settle/STR)
                  │                                                     │
                  └────────────────────────────────────────▶ P5 (social) ▶ P6 (Settings) ▶ P7 (cull)
```
- **P0 is the gate** — everything reads `task`. Build & ship it first; it alone delivers "drop the doc."
- **P1 and P2** can run in parallel after P0.
- **P5/P6/P7** are cross-cutting; start P5's notification table early if convenient.

## Per-phase ritual
For each phase: write migration → user `db push` → RPCs → components (DoD-compliant) → routes →
`cd /Users/huangjimin/thefin-community && npm run build` → i18n keys (zh/ja/fr) → commit → push. Keep old
surfaces alive until the new one replaces them (incremental retirement, never big-bang).

## Open questions — all resolved
- **P3 — RESOLVED:** matching (A) is the default — we want the ecosystem; direct name-and-go (B) is an
  always-available override. Build `match_candidates` (A) **and** `DirectAssign` (B).
- **P4 — RESOLVED:** STR stays **legible but quiet** (visible on My / profile / Settle; absent on board /
  roster / home). No contribution number on person cards.
- **P0 — RESOLVED:** task `state` = `open · doing · done`; coverage groups use `confirmed · checking ·
  potential`. One `state` column, validated against the group's allowed set.
- **P0:** task `state` set — is Open/Doing/Done enough, or do coverage groups need their own states as a
  first-class per-group vocabulary?
