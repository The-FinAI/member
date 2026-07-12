# Roles, Permissions, Ownership & Approval — the architecture

> **Status: PROPOSED (v0.1, 2026-06-19) — awaiting approval by the President.**
> Issue: #49. Once approved, permission-related changes must cite this document,
> and changes to *this document* are logged in the version history below (#48).
>
> This document is **descriptive of the current code** (every rule below is
> extracted from the deployed SQL gates and UI guards, with the function that
> enforces it), plus a small number of **⚠ pending** rows whose migrations exist
> in the repo but are not yet pushed to production. Nothing here is aspirational:
> if behavior on the site contradicts this document, one of the two is a bug —
> which is the point of having it (before this doc, "users are unsure whether a
> limitation is intentional or a bug", #49/#51).

---

## 0 · The model in one paragraph

The community is **bipartite**: **chapters hold people, working groups hold
projects**, and they meet at a project's **need**. Authority is granted three
ways: (a) being an **officer of a unit** (authority over that unit's people or
projects), (b) holding a **capability** via a community position (President
etc.), and (c) **owning** the object (yourself, your card's people, your
resources, your project's lead seat). Almost every backend rule is a composition
of five predicates:

| Predicate | True when… | Grants |
|---|---|---|
| `current_member_id()` | the logged-in user's member row | "self" rights |
| `manages_card(m)` | m is a **card** (no login yet) you steward | act on their behalf |
| `is_unit_officer(u)` | you hold a serving officer seat in unit u — or `manage_members` | unit authority |
| `is_unit_officer_of(m)` | you are an officer of member m's **home chapter** | chapter-people authority |
| `has_capability(k)` | one of your community positions grants capability k | global authority |

Two derived gates cover most of the UI:

- **`can_edit_member(m)`** = self **or** manages_card(m) **or** is_unit_officer_of(m)⚠ **or** `manage_members`
- **`can_edit_project(p)`** = `edit_any_project` **or** (p belongs to a WG **and** you're its officer) **or** you hold p's **leader seat** (or manage the card that does)

⚠ = in `20260615040000_officer_edit_chapter.sql`, **pending `db push`**. Until
pushed, production limits officer edits to *cards* (this is the #44 confusion).

---

## 1 · Role inventory

| Role | What it is | Purpose | Scope of authority |
|---|---|---|---|
| **Visitor** | no session | read the public login page | none |
| **Member** | a signed-in person with a claimed member row | do research work; keep their own record current | self only (own profile, own tasks, own resources); create **unattributed** project proposals |
| **Member card** | a person who hasn't signed up; a custodial record | exist in the roster so they can be staffed | none (not a login). Acted *for* by their steward until they sign in and **claim** the card |
| **Chapter Officer** (chair / secretary of a chapter) | officer seat in a unit of kind `chapter` | steward the chapter's **people**: skills, levels, availability; staff them onto needs; review their self-edits | their chapter's members only |
| **Working-Group Officer / Leader** | officer seat in a unit of kind `working_group` | steward the group's **projects**: adopt/create, edit, post needs, run the board, finish & settle | their group's projects only |
| **First Author (project leader)** | holds a project's `leader` slot (a seat, matched like any need) | run one project day-to-day | that project only (`manages_project`) |
| **President / Admin** | community **position** granting capabilities | govern: review queues, taxonomy, economy, access | global, via capabilities below |
| **Steering member** | position with `invite_members` only | invite officers | invite tool only |

**Capabilities** (granted to positions on `/admin/access` → Permissions):
`manage_members` · `invite_members` · `edit_any_project` · `manage_taxonomy` ·
`manage_guild` · `manage_resources` · `manage_stater` · `review_skillcard`.
A member's authority is the **union** across their positions; one person can
hold several roles at once (e.g. chapter officer + WG leader).

---

## 2 · Entity inventory

| # | Entity | Table(s) | What it is |
|---|---|---|---|
| E1 | Member / card | `member` | a person (kind `member`) or custodial card (kind `card`) |
| E2 | Chapter | `org_unit (kind=chapter)` | holds people |
| E3 | Working group | `org_unit (kind=working_group)` | holds projects |
| E4 | Unit membership / application | `org_unit_member` | who belongs to a unit; joining is applied-for and decided |
| E5 | Project | `project` | the living record: board, team, needs; owned by a WG via `org_unit_id` (may be **unattributed** = proposal) |
| E6 | Need (role slot) | `project_slot` | demand: a role a project needs (incl. the leader seat) |
| E7 | Assignment | `work_commitment` | supply meeting demand: a person seated into a slot with hours |
| E8 | Task | `task` | a unit of work on a project's board |
| E9 | Skill rating | `person_skill` | a person's skill at Learning / Independent / Lead |
| E10 | Availability | `member.monthly_hours` | hours/month a person can give |
| E11 | Resource | `resource` | compute/data/funding a holder can commit (reviewed before offerable) |
| E12 | Self-edit request | `member_change_request` | a member's own skill/hours edit awaiting officer review ⚠ |
| E13 | Review item | `forge_request` | anything submitted for governance review (cards, badges, resources, claims…) |
| E14 | Milestone | `project_milestone` | claimed output, verified to lift the payout |
| E15 | Settlement / STR | `stater_settlement`, `stater_ledger`, `stater_balance` | the credit economy: accrue → settle → spend |
| E16 | Taxonomy | `skill`, `project_type/status`, `venue`, `resource_type`, `gpu/api_model` | shared vocabularies |
| E17 | Announcement | `announcement` | pinned site-wide notices |
| E18 | Notification | `notification` | per-member inbox events |
| E19 | Position & capability | `position`, `capability`, `position_capability`, `member_position` | the access-control objects themselves |

---

## 3 · Permission matrix (role × entity)

Legend: ✓ = allowed · own = own/self objects only · unit = own chapter/group only ·
✗ = not allowed · ⚠ = pending migration. "Save" is not listed separately: **any
permitted Edit must persist** (a Save that silently drops is always a bug — the
#26/#43 class).

| Entity (action) | Member | Chapter Officer | WG Officer / 1st Author | President (capability) |
|---|---|---|---|---|
| **E1 member profile** view | ✓ | ✓ | ✓ | ✓ |
| create (add person → card) | ✗ | unit (`forge_card`) | ✗ | ✓ `manage_members` |
| edit skills/hours | own → **review** ⚠ (`member_change_submit`) | unit ⚠ / their cards: **direct** (`can_edit_member`) | ✗ | ✓ direct |
| archive / restore | ✗ | their cards (`member_archive`) | ✗ | ✓ |
| **E2/E3 unit** view | ✓ | ✓ | ✓ | ✓ |
| create / officer seats | ✗ | ✗ | ✗ | ✓ `manage_members` (`assign_org_officer`) |
| edit description | ✗ | own unit (`update_org_unit`) | own unit | ✓ |
| **E4 join a unit** apply | ✓ (`apply_to_unit`) / leave: ✓ | — | — | — |
| decide application | ✗ | own unit (`decide_unit_member`) | own unit | ✓ |
| **E5 project** view | ✓ | ✓ | ✓ | ✓ |
| create **unattributed proposal** | **✓ by design** (#51) (`create_project_phase1`, wg=null) | ✓ | ✓ | ✓ |
| create **under a WG** | ✗ | ✗ | own WG | ✓ `edit_any_project` |
| **adopt** proposal into WG | ✗ | ✗ | own WG (`forge_claim`) / release (`release_claim`) | ✓ |
| edit / status / archive | ✗ | ✗ | own WG or led project (`can_edit_project`) | ✓ |
| **E6 need** post / edit / close | ✗ | ✗ | own project (`forge_need`, `need_update`, `slot_close`) | ✓ |
| **E7 assignment** seat someone | ✗ | their chapter's people (`work_seat`, `seat_direct`) | own project | ✓ |
| remove / undo | ✗ | same (`unassign`) | own project | ✓ |
| commit own resource | holder only (`set_resource_commitment`) | — | — | — |
| **E8 task** add/edit/delete | ✗ | ✗ | own project (`task_*`) | ✓ |
| change own task's state | **✗ on prod — but the UI offers it** (gap G3 below) | — | own project | ✓ |
| **E9/E10 skills & availability** | own → review ⚠ | unit ⚠ / cards: direct | ✗ | ✓ |
| **E11 resource** add | own (`forge_resource`) → **review** | their cards' → review | ✗ | ✓ `manage_resources` |
| edit | own (`update_resource`) → re-review | their cards' | ✗ | ✓ |
| approve | ✗ | ⚠ their chapter's (`forge_decide`) | ✗ | ✓ `manage_resources` |
| **E12 self-edit request** decide | ✗ | their cards ⚠(+chapter) (`member_change_decide`) | ✗ | ✓ `manage_members` |
| **E13 review queue** decide | ✗ | items about their people ⚠ | items about their projects | ✓ (capability by item type) |
| **E14 milestone** claim | ✗ | ✗ | own project (`forge_milestone`) | ✓ |
| verify | ✗ | ✗ | ✗ | ✓ (`verify_milestone`) |
| **E15 settlement** submit | ✗ | ✗ | own project (`submit_settlement`) | ✓ |
| approve / mint / grant STR | ✗ | ✗ | ✗ | ✓ `manage_stater` |
| **E16 taxonomy** edit | ✗ | ✗ | ✗ | ✓ `manage_taxonomy` / `manage_guild` |
| **E17 announcement** manage | ✗ | ✗ | ✗ | ✓ `manage_members` |
| **E19 positions & capabilities** | ✗ | ✗ | ✗ | ✓ `manage_members` (grant/revoke chips) |

---

## 4 · Ownership model (per entity)

| Entity | Owner | Editor | Reviewer | Approver | Admin override |
|---|---|---|---|---|---|
| Member profile | the person | self; steward (if card); home-chapter officer ⚠ | home-chapter officer (self-edits ⚠) | same | `manage_members` |
| Member card | steward (creator/chapter) | steward | — | claimed by the person signing in (`claim`) | `manage_members` |
| Chapter / WG | its officers | its officers | — | — | `manage_members` |
| Unit membership | the member | — | unit officer | unit officer | `manage_members` |
| Project (unattributed) | creator (`created_by`) | creator | — | a WG adopts it (`forge_claim`) | `edit_any_project` |
| Project (in a WG) | the working group | WG officers + leader-seat holder | — | — | `edit_any_project` |
| Need / task | the project | project editors | — | — | `edit_any_project` |
| Assignment | person + project | the member's **home-chapter officer** (`is_unit_officer_of`) or card steward — *not* project editors (see G5/#53, decision pending) | capacity over-commit → review (`review_commitment_period`) | `manage_stater/resources/members` | same |
| Resource | its holder | holder / card steward | resource steward | `manage_resources` (⚠ + chapter officer for their people's) | `manage_resources` |
| Milestone | the project | project editors | admin | `edit_any_project` / `manage_stater` / `manage_resources` | same |
| Settlement / STR | the community | project lead drafts | reviewers | `manage_stater` | `manage_stater` |
| Taxonomy / announcements / positions | the community | — | — | `manage_taxonomy` / `manage_members` | President |

**Ownership transfer:** projects transfer between WGs via
`attach_project_to_unit` / `detach_project_from_unit` (either WG's officer, the
project lead, or admin); cards transfer to their person via **claim** on first
sign-in; everything else transfers only by admin.

---

## 5 · CRUD lifecycle (per entity, the intended shape)

Every entity follows one of three lifecycles:

**L-direct** (trusted edit): create → edit (persists immediately) → archive
(reversible by admin) — *no hard delete*.
Applies to: member profile edited by its officer/steward, project, need, task,
unit description, announcement.

**L-reviewed** (submit → review → apply): create/edit lands as a **pending
request**; a reviewer approves (change applies) or rejects (nothing changes);
the submitter can see their pending value.
Applies to: member self-edits (E12 ⚠), resources (approval_status:
pending → approved/rejected; edits re-enter review), unit join applications,
milestones (claimed → verified), settlements (submitted → under_review →
approved → settled), forge queue items (E13).

**L-append** (ledger, never edited): STR ledger entries, project history/log,
notifications — created by the system, immutable, never deleted.

Deletion policy, explicitly: **users archive; only admins restore; nobody hard-
deletes** (the only true deletes are a task row and an unposted need, both
low-stakes and re-creatable). If a record "can be deleted but cannot be
restored" (#49's observation), that's a bug against this policy.

---

## 6 · Approval workflow (who approves what)

| Submission | Approver | Where |
|---|---|---|
| Member self-edit (skills/hours) ⚠ | their chapter officer (or `manage_members`) | member profile → "Changes awaiting your review" |
| Resource (new / edited) | `manage_resources` steward (⚠ + chapter officer for their people) | Admin → Review inbox |
| Join a chapter / WG | that unit's officer | Admin → Unit applications |
| Over-capacity commitment | `manage_stater/resources/members` | Review inbox |
| Milestone claimed | admin (`verify_milestone`) | Review inbox |
| Settlement | `manage_stater` | Review inbox |
| Officer seats / capabilities | `manage_members` (President) | Admin → Officers & access |

---

## 7 · Known gaps & pending items (honest list)

1. **⚠ Pending migrations** (in repo, not yet in production):
   `officer_edit_chapter` (chapter officers edit *claimed* members + review their
   self-edits — the #44 fix), `member_change_review` (E12), `archive_close`,
   `release_recipients`. Rows marked ⚠ describe post-push behavior.
2. **Restore surface**: archive is admin-reversible in data, but there is no UI
   to list & un-archive yet (#34 follow-up).
3. **G3 — a task's owner cannot update their own task (backend), but the UI
   offers it**: `task_update` requires `can_edit_project` with **no owner
   exception**, while `/my` shows the owner Start/Reopen/Done controls. Found
   while fact-checking this document (the mock has no gate, so local tests
   pass). Proposed rule for approval: *a task's owner may change its `state`
   and `note` (not reassign or delete it)*. Implementation blocked until this
   document is approved (#49's own scope rule).
4. **Unattributed-project editing**: the creator can see their proposal (#51
   fix) but day-to-day editing before adoption is limited to admin; whether the
   creator should edit their own proposal pre-adoption is an **open design
   question** for approval here.
5. **G4 (#52)** — the create-project form offers **every** working group to any
   member; the backend rejects non-officers after they've filled the form.
6. **G5 (#53)** — Assign controls render for **any** officer (`canSeat`), but
   `work_seat` authorizes only the member's home-chapter officer — not even the
   project's own WG leader. This also exposed a **doc/code contradiction**: §4
   lists "project editors" among an assignment's editors, which the SQL does
   not allow. UNDEFINED until decided: *may a WG leader seat their own
   project's needs (Option B), or is staffing strictly the chapter officer's
   (Option A, current SQL)?* §4's row stands corrected to match the code until
   then.
7. This document does not yet cover RLS row-visibility nuances (all members can
   currently *view* nearly everything; Phase 1 is an open-book community).

---

## Version history (#48)

| Version | Date | Change | Trigger |
|---|---|---|---|
| v0.1 | 2026-06-19 | first complete draft, extracted from code | #49 (also answers #51, #44-class questions) |
| v0.1.1 | 2026-06-19 | gaps G4/G5 added from the first I-4 audit cycle; §4 assignment row corrected to match SQL (decision pending in #53) | #52, #53 |
