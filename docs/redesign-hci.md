# Rebuild from HCI — the decisive blueprint

*This supersedes `north-star.md`, `phase1-officer-reality.md`, and PRD-hci §1–13 by turning them into
one executable plan, now grounded in the full as-is map (`interaction-detail.md`). Those were the
reasoning; this is the build order. Every claim below points at a real component we inventoried.*

---

## 0. The one-sentence diagnosis

> **The app is an instrument for an *economy* (mint nominal STR → settle → liquid STR), but the only
> hand on it in Phase 1 is an *officer staffing a team*.**

Every screen is organized around the **data model** (cards, slots, needs, forge_requests, ledgers),
not the officer's **three jobs** (register people · staff projects · credit on publish). That single
mismatch produces every concrete defect the inventory found:

| HCI law broken | What the inventory shows (real components) |
|---|---|
| **One concept → one control.** | "Put a person on work" has **3 UIs + 4 RPCs**: `SlotSeater` (project page), `MatchConsole` inline seat (console), `SlotSeater`'s admin-only "Add directly" → `work_seat` / `seat_direct`. Posting a role has **2 forms**: `ForgeCard mode="need"` *and* `ResourceForgeForm mode="need"`. Badges have **3 paths**: `BadgeTree`, `ForgeCard mode="badge"`, Community award → `forge_badges` / `forge_badge`. |
| **Speak the user's language.** | UI still leaks `slot_kind`, `work_labor`, `req_access`, `nominal`, `forge_*`; internal ranks `apprentice/journeyman/craftsman/master` coexist with display `Beginner…Expert`. |
| **Match between system and the real world.** | "My time" is modeled as a *resource you forge* (`forge_resource`, name=`'My time'`) — but to an officer it's just **how many hours this person has**. Dead `saveLabor`/`addResource` code still sits in `MemberDetail`. |
| **Recognition over recall; visibility of constraints.** | Capacity (`usedHoursOf`, `over`/`under`) is invisible until it **greys out Confirm**. The officer can't see "12/20h used" *before* trying. |
| **Minimize ceremony.** | **Everything** funnels through one `forge_request` review queue — adding your own roster member, setting their hours, posting a role — even though the officer is a trusted proxy acting on their *own* unit. |
| **One model, not two.** | The home leads with a **claimable-STR mining ring** (`MiningCockpit`) — the *economy's* view — to a user who is a **staffing coordinator**. Two mental models collide on the first screen. |
| **Consistency.** | A project opens as a **drawer with an embedded body** *or* a **full page**; member card the same. Two patterns for one object. |

---

## 1. Six principles (the test for every screen)

1. **One user, one workbench.** Phase 1 has exactly one operator: the officer **player-coach**. Design the whole product as *their* bench. Members-logging-in and STR-as-hero are **Phase 2** — the same data, the view flipped.
2. **One concept = one word = one component = one gesture.** If two screens do the same act, they are the same component. Delete synonyms in code *and* copy.
3. **Direct manipulation over forms.** Staffing is "put A on B." Make it a **single gesture** (select a person → the roles they fit light up with their spare capacity → click to assign), not `openPicker → search → pickCard → amount → resource → confirm` across a drawer.
4. **Progressive disclosure of the economy.** STR is accounting. Show it **only where it becomes real** — a finished project's payout. Never lead with "claimable STR" for an officer.
5. **Make the constraint visible before it blocks.** Every person carries a **capacity bar** (`14/20h this month`). You see the budget, then spend it — you never hit a mystery-greyed button.
6. **Trust + undo, not review-everything.** An officer's edits to their *own* unit apply **immediately and reversibly**. The heavy queue is reserved for acts that **cross units** or **bear value** (badge grants, settlement payout).

---

## 2. Target architecture — surfaces

From the inventoried **~20 routes** to **3 work surfaces + 3 reference**:

| Surface | Replaces | What it is |
|---|---|---|
| **Bench** (home) | `MiningCockpit` + officer console + StartHere | The player-coach workbench: **two lanes**, *My work* (projects I'm on, my next action) and *My team* (my people, each with a capacity bar). The lanes are **live**: tap a free person → roles they fit glow; tap a role → who's free glows. Staffing happens here. |
| **Project** | `/projects/[id]` + drawer + `ProjectCardBody`/`SlotSeater`/`ProjectSlotCard` | One project: roles (filled / open), the **one** stage-action, links/meetings/milestones, finish & split. **One pattern** — drawer for peek, route for deep edit, never both bodies. |
| **Person** | `/members/[id]` + `MemberDetail` | One person: skills, **capacity**, projects, credit-so-far (quiet). |
| Directory | `/community` | Browse people / chapters / groups. Reference, not a workspace. |
| Wallet | `/wallet` | STR ledger. Quiet in P1; the **hero in P2**. |
| Settings | ~15 admin routes | **One review inbox** + catalog editors (skills, types, roles, venues, economy). |

The "Console" disappears as a separate place — its job *is* the Bench.

---

## 3. The interaction rebuilds (the heart)

### 3.1 Staffing — collapse 3 UIs + 4 RPCs into one gesture
**Today:** `SlotSeater` (project), `MatchConsole` inline (console), `SlotSeater` "Add directly" (admin) — three forms; `work_seat` + `seat_direct`.
**Target:** one **Assign** gesture, available wherever a person or a role appears:
- Select a **person** → every role they qualify for lights up, each annotated with *their* spare capacity ("can give 6 of 8h"). Click a role → an inline confirm pre-filled to the need's quota. Done.
- Select a **role** → qualified people light up, dimmed-with-reason if short on skill or hours.
- "**Add directly**" stops being a separate admin form: assigning a person to a project that has *no matching open role* simply **creates the role behind the scenes** (same gesture, system forges the slot). No second UI, no admin-only branch — the *permission* still gates it, the *interaction* is identical.
- One RPC surface: `assign(person, project, role?, hours)` (wrapping today's `work_seat`/`seat_direct`).

### 3.2 Capacity — a budget you can see
Every PersonChip shows `used/total h` as a bar. Over-allocation is shown as a **red overflow on the bar**, not only as a disabled Confirm. The officer scans the team and instantly sees who's free — the single number `phase1-officer-reality.md` says they actually want.

### 3.3 Hours ≠ a resource named "My time"
A person **has** `skills` + `monthly hours`. That's an attribute of the person, edited on their card — **not** a `forge_resource` call named `'My time'`. Compute/data/funding stay as real **Resources** (rare, `ResourceForgeForm`). Delete the dead `saveLabor`/`addResource` paths.

### 3.4 One form per act
- **Role** (was need): one picker — skill + level + hours/headcount. Kill `ForgeCard mode="need"`; keep one form.
- **Badge:** `BadgeTree` everywhere. Awarding to someone else = the same tree opened on their card. Kill `ForgeCard mode="badge"` and the Community award panel's separate `forge_badge` loop.
- **Resource:** one `ResourceForgeForm`, type-adaptive (already good) — minus the labor/"My time" special case (now a person attribute).

### 3.5 Review — three tiers, not one queue
| Tier | Acts | Mechanism |
|---|---|---|
| **Immediate + undo** | add/edit your own roster member, set hours, assign within your unit, post a role on your project | applies now; an Undo affordance; no queue |
| **Light review** (officer↔officer) | assign your person to *another* group's project; claim an unowned project | a notification the receiving officer accepts |
| **Value review** (admin) | badge grants (confer credit), settlement payout, capacity overrides | the queue stays **only here** |

This is the biggest ceremony cut: the officer's day-to-day stops asking permission to manage their own team.

### 3.6 Vocabulary — final, enforced in nav, buttons, copy, admin, tooltips
| Drop (banned) | Use |
|---|---|
| slot / open_need / work_labor | **Role** |
| seat / bind / forge / seat_direct | **Assign** |
| "My time" resource / monthly_quota | **Hours** (a person's capacity) |
| nominal / liquid STR as hero | **Credit** (quiet); STR is the ledger unit, not the headline |
| Mint done / settle / harvest | **Finish** → **Split the credit** |
| apprentice…master | **Beginner · Intermediate · Advanced · Expert** (DB keeps ranks; UI never shows the old words) |
| Forge queue | **Review inbox** |

### 3.7 One object pattern
**Card** (Person/Project/Role share one shell: type · status · title · one metric · one action) → **peek = drawer**, **deep = route**. Never a drawer hosting a full tabbed body. Kill the dual-body project rendering.

---

## 4. Component cull

Down to ~**8** components, one of each:
`PersonChip` (with capacity bar) · `ProjectCard` (roles + stage action) · `RoleRow` · `AssignSheet` (the single in-place assign confirm) · `SkillTree` (one picker, read = filled pips, edit = clickable) · `ResourceForm` (rare) · `Pipeline` (the stepper) · `ReviewItem`.

Delete: `SlotSeater`'s second/third paths, `ForgeCard` modes need+badge, `MiningCockpit` ring-as-hero, `StartHere` (folded into empty-states of the Bench), legacy `saveLabor`/`addResource`, and the **6 dead backend subsystems** (token economy, apply→accept→confirm join, stake commitments, skillcards, skill-exam+endorsement, resource offers, paid-leader bonds) via one legacy-purge migration.

---

## 5. Rollout — incremental, each step reversible (not big-bang)

A "彻底重构" that ships in one drop is the riskiest possible plan. Stage it so every phase is independently
useful and revertible:

- **A — Language & dedup (pure relabel + delete, zero data change).** Apply §3.6 vocabulary across nav/buttons/copy; delete the duplicate forms (`ForgeCard` need+badge), wire those entry points to the single component. *Ship, observe.*
- **B — One staffing gesture.** Replace the 3 seating UIs with the one Assign gesture (§3.1) + visible capacity bar (§3.2). Behind one `assign()` RPC wrapper.
- **C — Bench home.** Home becomes the two-lane player-coach workbench; demote the STR ring to a quiet credit number (§2.4, §4).
- **D — Review tiering.** Officer's own-unit edits go immediate+undo; queue shrinks to value/cross-unit acts (§3.5).
- **E — Cull.** Legacy-purge migration (6 dead subsystems) + surface reduction (~20 → 6 routes) + hours-as-attribute (§3.3).

Target end state: **6 surfaces · ~8 components · 6 nouns · 1 word per concept · 1 gesture per act.**

---

## 6. The acceptance test (for any future change)

> Would a lab coordinator who never read this doc sit down at the **Bench**, see *their people and their
> projects*, drag a free person onto an open role, and never once meet the words *slot, forge, nominal,
> seat, or harvest*? If the first thing they see is their own STR balance, or if one act needs two
> different forms, the change is pointed at the wrong user — or something must be removed.
