# Governance Changelog

> Issue #48. Records **every change to governance documents** — permanently,
> append-only, never overwritten. Current version: see [`VERSION.md`](VERSION.md).
>
> **Governance documents covered:** `docs/architecture.md` (roles, permissions,
> ownership, approval — #49) · `docs/audit-framework.md` (#50) ·
> `docs/permissions.md` (plain-language companion) · `docs/usability-sim.md`
> (verification requirements / Definition of Done) · `docs/user-journeys.md`
> (workflow rules for testing).
>
> **Update process (required for any governance change):**
> 1. a **governance issue** describing the change and its reason;
> 2. the **document update** itself;
> 3. an **entry here** (date · version · issue · summary · reason);
> 4. a **version increment** in `VERSION.md` (semver: major = model change,
>    minor = new rules/sections, patch = clarifications).
>
> Releases touching governance may not ship unless all four are present.

---

## v1.3.1 — 2026-08-23

**Trigger:** President follow-up — the market is not a tab, it is the app.

- All other surfaces removed (projects, people, community, guide, members,
  units, wallet, my, profile, officer, opportunities, str, styleguide) with
  their e2e specs. `/` now redirects to `/market`.
- Shell reduced to the concept: brand · language · avatar (email, Settle for
  President, sign out). Notifications, theme toggle, STR banner, onboarding
  quest and section nav removed.
- Remaining routes: `/market`, `/login` (magic link), `/admin` (President
  settlement door, reachable from the avatar menu / market Settle link only).
- Migration fix: `member_archive` keeps its original `default true` parameter
  (postgres cannot drop defaults via `create or replace`).

## v1.3.0 — 2026-08-23

**Trigger:** President directive — land the Market (concept v49) as Phase 1.

- `docs/architecture.md`: new **v0.3** section — permissions suspended for the
  `/market` surface (any signed-in member may act); settlement/minting stay
  President-gated; safety = openness + history + reversibility.
- New surface `/market`: single-page officer market (projects as toggle rows
  with author-role seats priced in STR, dual-track STR bar — nominal in pool
  vs settled — with member/group/chapter boards, member maintenance with
  account-link state, orphan-account linking, + New for project/group/chapter).
- Migrations `20260821010000` (authorship roles on openings) and
  `20260821020000` (open gates, verbatim bodies; account-linking RPCs).
- Tests: `tests/e2e/market.spec.ts` (M1–M7) per the Definition of Done.

## v1.2.0 — 2026-08-21

**Trigger:** merge of external audit branch `audit/full-crud-functional-audit`
(a teammate's agent, 2026-08-09; 27-finding CRUD audit in `audit.md` + F1–F12/
F19 remediation). Reviewed under the #50 framework before merge; suite green on
the branch itself.

### Changed
- **Self-edit surface narrowed (their F1, critical):** the `member` self-update
  RLS policy is replaced by **column-level grants** — a member may directly
  update only `affiliation` / `bio` / `links`; everything identity- or
  role-bearing requires `manage_members`, and skills/hours continue through
  officer review. *Aligns the code exactly with architecture v0.2 §3-E1.*
- **New gated RPCs:** `member_rename`, `member_set_availability` (both
  `can_edit_member`), `project_set_type`, `project_set_deadline` (both
  `can_edit_project`) — closing their F5/F7/F8/F11 CRUD gaps within the
  approved model. Migrations `202608090*` (pending push).
- **Dead code removed (their F12 = our R2):** 9 unreachable components deleted
  (MatchConsole, SlotBoard, SlotSeater, MemberCard, CardBinder, GettingStarted,
  StartHere, MiningCockpit, Leaderboard) — shrinking the gate-drift surface.
- Mock realism: `member.kind` corrected to the DB's `operator|card` domain.

### Review notes
- Their audit's F2 ("54/60 tests fail") was a runner-environment artifact —
  60/60 pass on both branches here; no code was changed to chase it.
- Follow-up: their new mock `project_set_*` handlers lack permission gates
  (fidelity nit); their remaining findings (F13–F27) are open recommendations.

---

## v1.1.0 — 2026-07-26

**Issues:** #49 (approved), #52, #53 (decided).

### Changed
- `docs/architecture.md` v0.1.1 → **v0.2, APPROVED** by the President.
  *Reason:* #49's approval gate cleared; permission work may now cite it.
- **Decision recorded — #53 Option A (strict bipartite):** staffing a person
  belongs to their home-chapter officer (or card steward / admin); project
  editors do not seat members. Follow-up audit found `assign()` and
  `work_seat()` had **contradictory gates** whose intersection broke both
  officer types for claimed members; unified in migration
  `20260726020000_assign_bipartite.sql` (pending push). Matcher UI renders
  Assign only where authorized; others get a route-to-chapter-officer cue.
- **G3 resolved:** a task's owner may change its `state`/`note` (migration
  `20260726010000_task_owner_update.sql`, pending push; mock mirrors it).
- **G4 (#52) resolved:** the create-project form offers only working groups the
  creator may attribute to; plain members' proposals start unattributed.
- Mock-fidelity: the mock now enforces the same gates as production for
  `assign`, `task_update`, `create_project_phase1` — so tests fail where
  production would fail.

---

## v1.0.1 — 2026-06-19

**Issues:** #52, #53 (filed by the first formal I-4 audit cycle under #50).

### Changed
- `docs/architecture.md` v0.1 → v0.1.1: gaps **G4** (create-form offers WGs the
  creator can't use, #52) and **G5** (Assign shown to officers `work_seat`
  rejects; §4 assignment-editor row corrected to match SQL — whether a WG
  leader may seat their own project is UNDEFINED pending decision in #53).
  *Reason:* audit findings must be reflected in the baseline document so later
  audits don't re-discover them (#50 §1 retro step).

---

## v1.0.0 — 2026-06-19

**Issues:** #49, #50, #48 (this framework), building on #37/#38.

### Added
- `docs/architecture.md` v0.1 (**PROPOSED**, awaiting President approval): role
  inventory, role×entity permission matrix, entity inventory, ownership model,
  CRUD lifecycles, approval workflows, known-gaps list (G1–G5).
  *Reason:* #49 — the platform operated without a formally approved permission
  model; users could not tell intentional limits from bugs (e.g. #51, #44).
- `docs/audit-framework.md` v1.0: the proactive audit loop (baseline → probe →
  finding → issue → human approval → remediation → pinned test → retro), 7
  instruments with cadences, standard finding format with `UNDEFINED` as a
  first-class outcome. *Reason:* #50 — problems were discovered mainly through
  user reports; a systematic, repeatable agent audit process was required.
- `CHANGELOG.md` + `VERSION.md` (this mechanism). *Reason:* #48 — governance
  changes were untraceable (what/when/why/which issue).

### Existing documents brought under governance
- `docs/usability-sim.md` — the Definition of Done (real-role round-trip,
  reload-persists, console-clean; a failing signal is a defect until proven
  otherwise) and the issue-understanding process. Originated from the #26/#43
  verification failures.
- `docs/permissions.md` — plain-language "who can do what" (#44 companion).
- `docs/user-journeys.md` — the workflow/persona testing rules (#30 retro).

### Standing rules (restated as governance)
- Agents **never close issues**; they comment and leave decisions to humans.
- **No remediation before human approval** of a finding (#50 §6).
- Every fix ships with a pinned regression test; user-found bugs get a
  "why did the audit miss it" retro.
