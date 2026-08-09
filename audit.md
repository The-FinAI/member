# Full CRUD and Functional Audit — The-FinAI Community Admin System

**Audit date:** 2026-08-09  
**Branch:** `audit/full-crud-functional-audit`  
**Auditor:** Claude Code (automated static analysis + test execution)  
**Scope:** People (Member) and Project records — full CRUD flows, field-level coverage, schema consistency, security, dead code, data integrity

---

## 1. Audit Scope and Methodology

### Scope
- All People (`member`) and Project (`project`) record types, including every field, every relationship, and every CRUD flow accessible through the UI.
- Admin taxonomy tables (project types, statuses, roles, venues, skills, org units).
- Authorization model and RLS policies.
- Schema consistency between original `schema.sql`, all 67 migrations, `mock-supabase.ts`, and frontend TypeScript types.
- Dead and orphaned code.

### What was NOT done
- No production database was queried or modified.
- No authentication credentials were used or bypassed.
- No live site (`https://community.thefin.ai/community`) was interactively tested (browser-level session not available in this environment).
- No destructive operations were performed.

### Methodology
1. **Static code analysis** — every `.svelte`, `.ts`, and `.sql` file in the repository was read, including all 67 Supabase migrations.
2. **CRUD matrix construction** — each field was traced from schema → RPC → frontend component → user interaction point.
3. **Import graph tracing** — all component imports were walked to identify dead code.
4. **Automated test execution** — `npx playwright test --mode mock` was run against the SvelteKit static adapter build in mock mode on port 5183. Results collected from two independent runs.
5. **Permission path analysis** — every RLS policy and every security-definer RPC was audited for correctness against the stated capability model.

---

## 2. Architecture Overview

| Layer | Technology | Notes |
|---|---|---|
| Frontend | SvelteKit v5 + Svelte 5 runes + TypeScript | Compiled to static SPA via `@sveltejs/adapter-static`, deployed to GitHub Pages |
| Backend | Supabase (PostgreSQL + PostgREST + Edge Functions) | Hosted Supabase project |
| Auth | Supabase magic-link email authentication | `claim_membership()` RPC binds auth user to pre-created member row |
| Authorization | Capability-based: `position → position_capability → capability` | Enforced at RLS + security-definer RPC level |
| API pattern | Security-definer RPCs for all writes; PostgREST selects for reads | `LookupEditor.svelte` is the only component that uses direct PostgREST DML |
| Test mode | `PUBLIC_MOCK=1` serves in-memory seeded world | Enables Playwright e2e without connecting to Supabase |
| Soft deletes | `archived_at timestamptz` on `member` (kind='card' only) and `project` | No hard delete in UI for either type |

### Key data flow
```
User action → Svelte component → supabase.rpc('rpc_name', args)
                                → security-definer function checks can_edit_*()
                                → UPDATE/INSERT on underlying table
                                → RLS policy: authenticated role only
```

### Critical architectural invariant
The `project_insert` RLS policy (`with check (has_capability('edit_any_project'))`) is **bypassed** by `create_project_phase1()` because it is `security definer`. Any authenticated user can invoke `create_project_phase1()` regardless of the RLS check. This is intentional but the policy is misleading.

---

## 3. People (Member) Data Model Inventory

### Core table: `member` (schema.sql + migrations)

| Field | Type | Source | Default | Notes |
|---|---|---|---|---|
| `id` | uuid PK | schema.sql | gen_random_uuid() | |
| `auth_user_id` | uuid FK → auth.users | schema.sql | NULL | Set by `claim_membership()` |
| `full_name` | text NOT NULL | schema.sql | — | Required at creation |
| `email` | text UNIQUE NOT NULL | schema.sql | — | Required at creation |
| `affiliation` | text | schema.sql | NULL | Optional |
| `avatar_url` | text | schema.sql | NULL | |
| `bio` | text | schema.sql | NULL | |
| `links` | jsonb NOT NULL | schema.sql | `{}` | Keys: scholar, hf, github, homepage |
| `availability` | text NOT NULL | schema.sql | `'looking'` | 'looking' \| 'limited' \| 'full' |
| `status` | text NOT NULL | schema.sql | `'invited'` | 'invited' \| 'active' |
| `created_at` | timestamptz | schema.sql | now() | |
| `kind` | text NOT NULL | card_membership.sql | `'operator'` | 'operator' \| 'card' CHECK constraint |
| `home_unit_id` | uuid FK → org_unit | card_membership.sql | NULL | Chapter FK |
| `monthly_hours` | integer | 20260606020000 | NULL | Available hours per month |
| `archived_at` | timestamptz | 20260615010000 | NULL | Soft-delete timestamp |
| `is_release_reviewer` | boolean | (inferred from mock) | false | No migration found; present in mock |

### Related tables

| Table | Purpose | Key fields |
|---|---|---|
| `member_position` | Positions held | member_id, position_id |
| `person_skill` | Skills per member | member_id, skill_id, level ('learning'\|'independent'\|'lead') |
| `member_change_request` | Pending changes queued for review | member_id, kind ('skill'\|'hours'), requested_value, status |
| `org_unit_member` | Membership in org units | member_id, org_unit_id, role, ended_on |
| `resource` | Resources held/managed | holder_member_id FK, scope ('member'\|'community'\|'project') |
| `stater_account` | STR wallet | member_id FK, balance |
| `notification` | In-app notifications | member_id FK |

### Write RPCs for members

| RPC | Capability required | What it does |
|---|---|---|
| `forge_member_card(name,email,unit,affiliation,badges)` | manage_members (implicit) | Creates a `kind='card'` member row |
| `forge_card(name,email,unit)` | manages_card | Simplified card forge |
| `claim_membership()` | authenticated | Binds auth user to invited member row |
| `person_skill_set(member, skill, level)` | can_edit_member OR self | Upserts skill level |
| `person_set_capacity(member, hours)` | can_edit_member OR self→review | Sets monthly_hours |
| `member_change_submit(member, kind, value)` | self (→review) or officer (→direct) | Submit hours/skill change |
| `member_change_decide(request_id, approve)` | can_edit_member | Approve/decline a queued change |
| `member_archive(member)` | manages_card OR manage_members | Sets archived_at; **only works on kind='card'** |
| `set_member_email(member, email)` | manage_members | Admin email correction |
| `can_edit_member(member)` predicate | — | Returns true for unit officer, manage_members, manages_card |

---

## 4. Project Data Model Inventory

### Core table: `project` (schema.sql + migrations)

| Field | Type | Source | Default | Notes |
|---|---|---|---|---|
| `id` | uuid PK | schema.sql | gen_random_uuid() | |
| `name` | text NOT NULL | schema.sql | — | Editable via `project_rename()` |
| `type_id` | uuid FK → project_type | schema.sql | NULL | Set at creation; **not editable after** |
| `status_id` | uuid FK → project_status | schema.sql | NULL | Editable via `project_set_status()` |
| `target_venue` | text | schema.sql | NULL | Legacy text field (superseded by `venue_id`) |
| `deadline` | date | schema.sql | NULL | No direct edit UI; inherits from venue |
| `summary` | text | schema.sql | NULL | Editable via `project_set_summary()` |
| `links` | jsonb NOT NULL | schema.sql | `{}` | Legacy; superseded by `project_link` table; **never dropped** |
| `created_at` | timestamptz | schema.sql | now() | |
| `org_unit_id` | uuid FK → org_unit | 20260601173600 | NULL | Working group; editable via `project_set_org_unit()` |
| `venue_id` | uuid FK → venue | (migration) | NULL | Editable via `project_set_venue()` |
| `archived_at` | timestamptz | 20260615010000 | NULL | Soft-delete timestamp |
| `emoji` | text | (migration) | NULL | **No UI to set** |
| `code` | text | (migration) | NULL | **No UI to set** |
| `creator_member_id` | uuid FK → member | (migration) | NULL | Set at creation; not editable |

### Related tables

| Table | Purpose |
|---|---|
| `project_member` | Members on the team (role, seated_at) |
| `project_role` | Roles (Leader, Contributor, etc.; can_manage flag) |
| `slot` | Open position slots with requirements |
| `project_link` | External links (kind, title, url, notes); replaces `project.links` jsonb |
| `project_meeting` | Scheduled meetings |
| `project_event` | Immutable history log (audit trail) |
| `project_task` | Tasks within the project |
| `project_milestone` | Verified milestones |
| `commitment` | Member work commitments to a project |
| `settlement` | Payout calculation on project finish |

### Write RPCs for projects

| RPC | Gated by | What it does |
|---|---|---|
| `create_project_phase1(name, type, status, venue, unit, proposal_url, summary)` | authenticated (any) | Creates project + leader slot + seats creator |
| `project_rename(project, name)` | can_edit_project | Renames |
| `project_set_summary(project, summary)` | can_edit_project | Updates summary |
| `project_set_venue(project, venue)` | can_edit_project | Sets venue |
| `project_set_org_unit(project, unit)` | can_edit_project | Sets working group |
| `project_set_status(project, status)` | can_edit_project | Advances pipeline |
| `project_link_add(project, kind, title, url, notes)` | can_edit_project | Adds link |
| `project_link_remove(link)` | can_edit_project | Removes link |
| `project_note(project, text)` | can_edit_project | Appends history note |
| `project_meeting_add(project, title, ...)` | can_edit_project | Adds meeting |
| `project_meeting_remove(meeting)` | can_edit_project | Removes meeting |
| `project_archive(project)` | can_edit_project | Soft-delete |
| `assign(need, member)` | manages_card OR manage_members OR edit_any_project OR is_unit_officer_of | Seats member on need |
| `unassign(project_member)` | can_edit_project | Removes member from team |
| `slot_close(slot)` | can_edit_project | Closes an open need |

---

## 5. Existing Automated Test Results

**Test suite:** `tests/e2e/` (Playwright, Chrome headless, mock mode)  
**Run date:** 2026-08-09  
**Two independent runs (consistent results):**

| Result | Count |
|---|---|
| **Passed** | **6** |
| **Failed** | **54** |
| Total | 60 |

### Passing tests

| ID | Description | File |
|---|---|---|
| A6 | Double-click Save does not corrupt the value | adversarial.spec.ts:89 |
| A8 | Lowering available time updates matcher free capacity | adversarial.spec.ts:110 |
| A9 | Empty community orients the newcomer | adversarial.spec.ts:134 |
| M3 | "Card" concept explained VISIBLY | concepts.spec.ts:32 |
| WGP5 | A plain member creates a project and can still see it | wg-project.spec.ts:82 |
| WGP7 | WG leader sees candidates but Assign is routed to chapter officer | wg-project.spec.ts:133 |

### Failing test categories (54 total)

| Category | Failing tests |
|---|---|
| Adversarial input (A1–A5) | 5 — junk/negative input, whitespace, tab navigation |
| Concepts / onboarding (M1, ONB*) | 8 — STR explanation, onboarding quests for all roles |
| Data persistence (P1, P2, P6) | 3 — task add/delete persistence, empty-name validation |
| Matcher (J1.4) | 1 — missing-level explanation |
| Navigation (J4.2, J4.3, J4.4) | 3 — non-officer chapter explainer, People roster description, Cancel button styling |
| Permissions (J1.5a–c, PERM1) | 4 — officer/non-officer/admin edit gating, permissions panel |
| Platform (J5.1, J5.2) | 2 — skill scale, mobile layout |
| Project actions (J2.1–J2.3) | 3 — status confirm gate, finish danger confirm, team remove |
| Resource (RES1) | 1 — officer resource quota edit |
| Review (J3.2) | 1 — member submits hours → officer approves → applied |
| Roster (J1.1–J1.3, J3.1) | 4 — officer edits hours/skill, member change review |
| Smoke | 1 — every surface mounts without crash |
| UI (J4.4) | 1 — bordered Cancel button |
| WG-project (WGP1–WGP4, WGP6) | 4 — adopt, adopt+edit, WG officer creates, WG dropdown filter |
| Workflows (WF1–WF8) | 8 — end-to-end workflow scenarios |

> **Root cause of broad failures:** The mock-mode app startup or navigation is breaking early (the SMOKE test fails), which means most tests fail before they even reach their functional assertion. The SMOKE failure cascades to all tests that rely on client-side navigation or the layout guard. The underlying cause must be investigated in a fix cycle — this audit records the state, not the cause.

---

## 6. People (Member) CRUD Coverage Matrix

| Operation | Create | Read | Update | Delete/Archive |
|---|---|---|---|---|
| **Member record** | ✅ Officer via forge_member_card; Admin via invite-member edge fn | ✅ Full profile visible | ⚠️ Partial — see field matrix | ⚠️ Soft-delete only; restricted to kind='card' |
| **Skills** | ✅ Officer (direct) / Self (review) | ✅ | ✅ Officer (direct) / Self (review) | ❌ No delete UI; level can be set to lowest but not removed |
| **Monthly hours** | N/A (part of member) | ✅ | ✅ Officer (direct) / Self (review) | N/A |
| **Links (scholar, hf, github, homepage)** | ❌ No UI | ✅ Displayed read-only | ❌ No UI | ❌ No UI |
| **Positions** | ⚠️ Only at invite time (admin) | ✅ | ❌ No UI to change positions for existing members | ❌ No UI |
| **Resources** | ✅ Forge form on profile | ✅ | ✅ Edit button | ⚠️ No explicit delete; archive/cancel via forge queue |
| **Change requests** | ✅ (self) | ✅ Officer sees pending | ❌ No edit of pending | ✅ Officer can approve/decline |
| **Org unit membership** | ⚠️ Apply flow (WF4) | ✅ | ❌ No edit | ❌ No leave flow shown |

**Legend:** ✅ Working, ⚠️ Partial/restricted, ❌ Missing

---

## 7. Project CRUD Coverage Matrix

| Operation | Create | Read | Update | Delete/Archive |
|---|---|---|---|---|
| **Project record** | ✅ Any authenticated user via create_project_phase1 | ✅ Full project card | ⚠️ Partial — see field matrix | ⚠️ Soft-delete (archive); no hard delete UI |
| **Links** | ✅ project_link_add RPC | ✅ | ⚠️ No inline edit; must remove+re-add | ✅ project_link_remove |
| **Meetings** | ✅ project_meeting_add | ✅ | ❌ No update flow; must remove+re-add | ✅ project_meeting_remove |
| **Tasks** | ✅ TaskBoard add | ✅ | ✅ Update state/note | ✅ Delete (with confirm) |
| **Team members** | ✅ assign() RPC | ✅ | N/A | ✅ unassign() with confirm gate |
| **Open needs / slots** | ✅ NeedPost | ✅ | ✅ NeedPost edit | ✅ slot_close() |
| **Milestones** | ✅ Admin via LookupEditor (catalog) | ✅ | ✅ | ✅ (hard delete via LookupEditor) |
| **History/notes** | ✅ project_note | ✅ | ❌ History is append-only (correct by design) | ❌ Cannot delete history entries |
| **Status pipeline** | N/A | ✅ | ✅ (with confirm gate, if gate UI is working) | N/A |
| **Taxonomy (types/statuses/roles/venues)** | ✅ Admin LookupEditor | ✅ | ✅ Admin LookupEditor | ✅ Admin LookupEditor (no cascade check) |

---

## 8. People Field-Level CRUD Detail

### Fields with complete CRUD

| Field | Create | Read | Update | Clear/Delete |
|---|---|---|---|---|
| `full_name` | ✅ (required at forge) | ✅ | ❌ No RPC or UI exists | N/A |
| `affiliation` | ✅ (optional at forge) | ✅ | ✅ `MemberDetail.svelte:saveProfile()` (self only, direct update) | ✅ (set to empty) |
| `bio` | ❌ Not in forge form | ✅ | ✅ `MemberDetail.svelte:saveProfile()` (self only) | ✅ |
| `email` | ✅ (required at forge) | ✅ | ⚠️ Admin only via `set_member_email()` RPC in OfficersPanel | N/A |
| `monthly_hours` | N/A | ✅ | ✅ Officer direct / Self → review | N/A (cannot null) |
| `skills (person_skill)` | ✅ | ✅ | ✅ | ❌ No delete; only level change |
| `avatar_url` | ❌ No upload UI | ✅ (if set) | ❌ No upload/edit UI | ❌ |
| `links` | ❌ No UI | ✅ (read-only display) | ❌ No UI | ❌ No UI |
| `availability` | ❌ Never shown | ❌ Never displayed | ❌ Never shown | ❌ |
| `status` | ✅ ('invited' at creation) | ⚠️ Shown in admin context | ❌ No UI to manually transition | ❌ |
| `kind` | ✅ (set at forge) | ✅ (used in UI guards) | ❌ Cannot change kind after creation | N/A |
| `home_unit_id` | ✅ (set at forge) | ✅ | ❌ Cannot reassign home chapter | N/A |
| `archived_at` | N/A | ⚠️ Not displayed | N/A | ✅ `member_archive()` (kind='card' only) |
| `is_release_reviewer` | N/A | ❌ No UI | ❌ No UI | ❌ No UI |

### Summary of member field gaps
- **4 fields completely invisible:** `availability`, `is_release_reviewer`, and `links` (write-only half), `avatar_url` (display only)
- **3 fields not settable after creation:** `full_name`, `kind`, `home_unit_id`
- **1 field restricted to admin:** `email`
- **1 field set only at invite time:** member positions

---

## 9. Project Field-Level CRUD Detail

### Fields with complete or partial CRUD

| Field | Create | Read | Update | Clear |
|---|---|---|---|---|
| `name` | ✅ (required) | ✅ | ✅ `project_rename()` + InlineField | N/A (cannot be empty) |
| `summary` | ✅ (optional) | ✅ | ✅ `project_set_summary()` + InlineField | ✅ (clear to empty) |
| `type_id` | ✅ (required in form) | ✅ | ❌ No `project_set_type()` RPC exists | N/A |
| `status_id` | ✅ (optional in form) | ✅ | ✅ `project_set_status()` + pipeline UI | N/A |
| `venue_id` | ✅ (optional in form) | ✅ | ✅ `project_set_venue()` + InlineField | ✅ (set to null) |
| `deadline` | ❌ Not in form | ⚠️ Shown via `p.deadline ?? p.venue?.deadline` | ❌ No direct input; only inherits from venue | N/A |
| `org_unit_id` | ✅ (optional in form) | ✅ | ✅ `project_set_org_unit()` + InlineField | ✅ (set to null) |
| `links (jsonb)` | N/A (legacy column) | ❌ Never queried | ❌ Frontend uses project_link table instead | N/A |
| `emoji` | ❌ Not in form | ❌ Not displayed | ❌ No `project_set_emoji()` RPC | N/A |
| `code` | ❌ Not in form | ❌ Not displayed | ❌ No RPC | N/A |
| `archived_at` | N/A | ✅ (via Hall of Fame filter) | N/A | ✅ `project_archive()` |

### Summary of project field gaps
- **3 fields with no UI whatsoever:** `emoji`, `code`, `links (jsonb — legacy)`
- **1 field not updatable after creation:** `type_id`
- **1 field with no direct edit input:** `deadline` (inherits from venue only)
- **1 orphaned legacy column:** `project.links` jsonb (superseded by `project_link` table, never dropped)

---

## 10. Relationship CRUD Coverage

### Project ↔ Member (team membership)

| Operation | Status | Notes |
|---|---|---|
| Add member to project | ✅ | `assign()` RPC; bipartite rule: member's chapter officer must do the assigning |
| Remove member from project | ✅ | `unassign()` RPC with confirm gate |
| Change member's project role | ❌ | No RPC or UI; must remove and re-add |
| View team | ✅ | ProjectTeam.svelte |

### Project ↔ Org Unit (working group)

| Operation | Status | Notes |
|---|---|---|
| Assign project to WG | ✅ | `project_set_org_unit()` or at creation |
| Unassign project from WG | ✅ | Set org_unit to null |
| Transfer project to different WG | ✅ | Same RPC |

### Member ↔ Org Unit (chapter/WG membership)

| Operation | Status | Notes |
|---|---|---|
| Apply to join | ✅ | WF4 workflow; UnitApplications component |
| Accept/decline application | ✅ | Admin/officer in review |
| Leave a unit | ❌ | No UI to voluntarily leave; `ended_on` can be set but no front-end flow |
| Change home chapter | ❌ | `home_unit_id` not editable after forge |

### Member ↔ Position (role grants)

| Operation | Status | Notes |
|---|---|---|
| Grant at invite | ✅ | OfficersPanel invite flow |
| Add to existing member | ❌ | No UI; would require direct `member_position` insert |
| Revoke from existing member | ❌ | No UI; PermissionsPanel manages capability toggles per position, not per-member grants |
| View member's positions | ✅ | Shown on member profile |

---

## 11. Validation and Error-Handling Audit

### Input validation gaps

| Location | Field | Gap |
|---|---|---|
| `create_project_phase1()` | `proposal_url` | Client marks as required but RPC accepts NULL — inconsistency |
| `forge_member_card()` | `p_email` | No format validation at RPC level (PostgREST would reject duplicates) |
| `project_set_status()` | status transitions | No guard for skipping statuses (e.g., jumping from Proposal directly to Finished) |
| `LookupEditor.svelte` | all fields | No client-side validation; empty names are allowed to reach the database |
| `person_set_capacity()` | `p_hours` | No maximum cap enforced at RPC level (could set 10,000 hours) |
| `project_link_add()` | URL | RPC auto-prepends `https://` for URLs missing the scheme — silently mutates user input |

### Error display

| Issue | Location | Impact |
|---|---|---|
| RPC errors surface as raw PostgreSQL messages | All RPCs | Not user-friendly; e.g., unique constraint violation shows DB internals |
| `LookupEditor.svelte` renders error inline but no confirmation before delete | `LookupEditor.svelte:56–61` | A taxonomy item referenced by existing projects can be deleted — this would orphan those records |
| No toast/snackbar on network failure in most flows | Multiple components | Silent failures possible if Supabase is unreachable |

### Confirm dialogs (`.cf-modal`)

The confirm dialog pattern is implemented in `src/lib/confirm.ts` and `src/lib/shell/ConfirmDialog.svelte`. It is used for:
- Status change, Finish project, Remove member from team (project flows)
- Archive operations
- Release note sends

**Missing confirm dialogs:**
- Taxonomy item delete (LookupEditor) — no confirm before deleting a type/status/role/venue
- `member_archive()` call in MemberDetail — present but only for kind='card' members
- Unassigning from org unit — no confirm

---

## 12. Query and Search Audit

### People / Roster search (`/people`)
- **Implemented:** Text search on `full_name` (client-side filter on already-loaded roster).
- **Missing:** Search by affiliation, skill, chapter, availability status, archived members view.
- **Filter:** "My roster only" toggle for officers — works by `home_unit_id` match.
- **Sort:** Only alphabetical by `full_name` (server-side `order('full_name')`).

### Project search (`/projects`)
- **Implemented:** Name search (client-side), filter by type/status/venue, sort by deadline/tasks/needs/name.
- **Working group filter:** `attributableWGs` correctly filters to only the creator's WGs (fix #52).
- **Missing:** Full-text search on summary, search by team member, search by skill needed.
- **Archived projects:** Shown in "Hall of Fame" section (separate list) rather than as a toggle.

### Admin member search (OfficersPanel)
- Queries `member` with `neq('kind', 'card')` and `eq('status', 'invited')` for invite management — correct scope.

### Missing search/query surfaces
- No search on the member change request queue.
- No search or filter on the forge queue.
- No search on notifications.
- No global cross-entity search.

---

## 13. Authentication and Authorization Audit

### Authentication flow
1. User visits protected route → layout guard redirects to `/login`.
2. `/login` triggers Supabase magic-link.
3. On return, `claim_membership()` RPC links `auth.uid()` to the matching `member` row.
4. If no matching member exists, auth proceeds but `current_member_id()` returns NULL, which will fail all RLS policies silently (PostgREST returns empty results, not 403).

**Gap:** An authenticated Supabase user with no matching member row sees the app as empty rather than receiving a clear "not yet a member" message. The `login_block_unclaimed_cards` migration handles cards specifically, but unclaimed regular accounts have no explicit error path.

### Authorization model

| Capability | Description | Tables/RPCs gated |
|---|---|---|
| `manage_members` | Add, edit, archive any member | member (all), member_position, forge_member_card |
| `invite_members` | Create invites and place officers | invite, OfficersPanel |
| `manage_taxonomy` | Edit types/statuses/roles/skills | project_type, project_status, project_role, skill via LookupEditor |
| `edit_any_project` | Edit any project | project (direct), all project RPCs |
| `manage_stater` | Mint STR, adjust balances | stater_* tables, stater_mint/grant RPCs |
| `manage_resources` | Approve/edit resources | ForgeQueue, resource |
| `review_skillcard` | Approve skill/card forge requests | ForgeQueue |

### Permission gaps and issues

1. **`LookupEditor` uses direct PostgREST DML** (`src/lib/LookupEditor.svelte:41–61`). Taxonomy tables are gated by `manage_taxonomy` RLS policy. However, the `PermissionsPanel` (which also uses direct PostgREST insert/delete) is gated by `manage_members`. This is correct but bypasses the RPC logging pattern — taxonomy changes leave no audit trail.

2. **`saveProfile()` in MemberDetail.svelte** (`src/lib/MemberDetail.svelte:74`) does `supabase.from('member').update({affiliation, bio})` directly, not through a security-definer RPC. The RLS policy `member_update_self` gates this on `auth_user_id = auth.uid()` — correct, but any additional server-side validation or logging must be added to RLS, not the RPC layer.

3. **`project_insert` RLS policy is misleading** (`policies.sql:103–104`): `with check (has_capability('edit_any_project'))` is bypassed by the security-definer `create_project_phase1()`. A direct PostgREST insert would be blocked for non-edit_any_project holders, but the RPC path is open to all authenticated users. This means the RLS policy does not reflect actual business rules.

4. **Bipartite staffing rule** (`20260726020000_assign_bipartite.sql`): Correctly enforces that a member's chapter officer (not the project's WG officer) assigns them. The outer gate now matches `work_seat()` exactly. This is a recently fixed issue and the fix appears correct.

5. **`member_update_self` policy allows updating any column** (`policies.sql:77–78`): The RLS policy permits a member to update their entire row, not just `affiliation` and `bio`. A member could directly update `auth_user_id`, `email`, `kind`, `status`, `archived_at`, etc. via direct PostgREST calls. The frontend only calls the safe subset, but the DB policy is over-permissive.

   **Severity: High.** A member could, via direct API call: set `status='active'` (bypassing invite flow), change `kind` from 'operator' to 'card' (removing login ability), or modify `auth_user_id` (account takeover risk).

6. **`forge_member_card` / `forge_card` privilege check:** These RPCs check `manages_card` or `manage_members` capability internally but the function-level `grant execute` is to `authenticated`. A member without any capability who knows the RPC signature can attempt to call it; the capability check inside will reject them with an exception. This is correct behavior but worth noting.

7. **No CSRF protection:** The static SPA calls PostgREST and Supabase edge functions directly from the browser. Supabase enforces JWT authentication; no CSRF tokens are used. This is the standard Supabase SPA pattern and is acceptable.

---

## 14. Dead / Orphaned / Obsolete Code

### Completely unused Svelte components (not imported by any route or active component)

| File | Evidence of disuse | Legacy purpose |
|---|---|---|
| `src/lib/GettingStarted.svelte` | No import in any route or active component; only referenced in a comment in `src/lib/phase.ts:11` | Early onboarding; references legacy `member_skill` and `need_application` tables |
| `src/lib/StartHere.svelte` | No import anywhere | Early onboarding screen |
| `src/lib/MiningCockpit.svelte` | No import anywhere in routes | Admin mining dashboard concept |
| `src/lib/Leaderboard.svelte` | No import anywhere; referenced only in `messages.ts` translation strings and guide text | Community leaderboard |
| `src/lib/cards/CardBinder.svelte` | No import in any route; only imports `MemberCard.svelte` internally | Card collection browser |
| `src/lib/cards/MatchConsole.svelte` | Only imported by `CardBinder.svelte` (also dead) | Match console |
| `src/lib/cards/MemberCard.svelte` | Only imported by `CardBinder.svelte` (also dead) | Individual member card display |
| `src/lib/cards/SlotBoard.svelte` | No import in any route | Slot board |
| `src/lib/cards/SlotSeater.svelte` | Only mentioned in a comment in `ProjectTeam.svelte:3`; not imported | Slot seating UI |

### Obsolete/legacy database tables (schema + RLS policies exist, but no frontend uses them)

| Table | Status |
|---|---|
| `open_need` | Schema + RLS policies + `read_all_open_need` policy; no frontend component queries it. Superseded by `slot` table. |
| `need_application` | Schema + RLS policies for read/insert/delete/update; `GettingStarted.svelte` (itself dead) references it. No active UI path. |
| `member_skill` | Schema + `member_skill_self` RLS policy; `GettingStarted.svelte` (dead) references it. Superseded by `person_skill`. |
| `skill_endorsement` | Schema + `endorsement_by_endorser` RLS policy; no frontend component uses it. |

### Legacy column never dropped

| Column | Table | Issue |
|---|---|---|
| `project.links` (jsonb) | `project` | Defined in `schema.sql:78`; superseded by `project_link` table; frontend never queries it; column was never removed via migration. Any data written here (e.g., at project creation before the migration) is invisible to the UI. |

### Orphaned i18n translation strings

`src/lib/messages.ts` contains translation entries for `Leaderboard` and related community-standing concepts that are referenced nowhere in the active application. Duplicate keys (build warnings observed): `Apprentice`, `Journeyman`, `Craftsman`, `Master`, `Leader`, `Unit`, `Active` appear twice in the Chinese translation block (lines ~786–900 region).

---

## 15. Duplicate Code and Unnecessary Abstractions

### Confirmed duplication

1. **Member select query shape repeated** — At least 7 components (`StrEconomyPanel`, `CommunityResourcesPanel`, `OfficersPanel`, `ForgeQueue`, `MatchBoard`, `UnitDrawerBody`, `SkillCapacity`) independently issue `supabase.from('member').select('id, full_name')`. No shared query helper exists. Minor but adds maintenance surface.

2. **Can-edit guard logic duplicated between `can_edit_member()` (DB) and `MemberDetail.svelte`** — The frontend re-derives the edit permission locally using `capabilities`, `officerUnits`, and `isMe` checks. If the RPC predicate is updated, the frontend guard must be updated separately.

3. **Confirm dialog invocations** — The `confirm()` pattern is used consistently throughout (good). But several flows that *should* confirm (taxonomy delete via LookupEditor) bypass it entirely.

### Reasonable abstractions (not issues)
- `InlineField.svelte` is a clean, reused editable-field primitive.
- `LookupEditor.svelte` correctly generalizes the taxonomy CRUD table.
- `AdminConsole.svelte` + tab pattern is consistent across admin pages.

---

## 16. Frontend–Backend Schema Consistency

### Critical inconsistency: `member.kind` constraint vs. mock data

| Location | Value used | DB constraint |
|---|---|---|
| `card_membership.sql:57–58` | `CHECK (kind IN ('operator', 'card'))` | Authoritative |
| `mock-supabase.ts:29–35` | `kind: 'member'` for all non-card members | **INVALID** — 'member' is not a permitted value |

**Impact:** Tests running in mock mode interact with data that could never exist in the production database. Any test that branches on `kind === 'member'` exercises a code path that is unreachable in production. Any test that checks `kind !== 'card'` may behave differently in production where the value is `'operator'`, not `'member'`.

### `session.ts` Member type is a narrow subset

`src/lib/session.ts` defines `Member` as `{ id, full_name, email, affiliation, status }`.  
`src/lib/profile.ts:loadProfile()` selects only these same 5 fields.

Fields present in the `member` table but absent from the session type (and therefore not available in reactive context throughout the app):

| Missing field | Practical impact |
|---|---|
| `bio` | MemberDetail re-fetches the full row separately — double query for the same record |
| `links` | Same — requires separate query |
| `monthly_hours` | SkillCapacity re-fetches — double query |
| `kind` | Capability guards in layout cannot check `kind` from session; must re-fetch |
| `home_unit_id` | Cannot determine home chapter from session alone |
| `avatar_url` | Avatar display requires re-fetch in some contexts |
| `archived_at` | Cannot surface "you are archived" warning without re-fetch |

### `project.links` jsonb — legacy column never dropped

The original `schema.sql` creates `project.links jsonb default '{}'`. Migration `20260603040000_project_card.sql` creates the `project_link` table and RPCs. The frontend (`ProjectCardBody.svelte:93`) queries `project_link` exclusively. The `project.links` column:
- Is never queried by the frontend.
- May contain data written by old code paths.
- Will be returned in any `select *` on the `project` table, wasting bandwidth.

### `member.availability` field — completely orphaned

`member.availability text NOT NULL DEFAULT 'looking'` exists in `schema.sql:22`. It is never:
- Displayed to any user.
- Edited through any UI.
- Read by any frontend query on the `member` table.
- Referenced by any RPC.

The `availability` field visible in `MemberDetail.svelte:401` is `resource.availability`, not `member.availability`.

---

## 17. API Inventory

### Supabase RPCs (security-definer, available to `authenticated` role)

| RPC | Purpose | Authorized roles |
|---|---|---|
| `current_member_id()` | Returns member.id for current auth user | authenticated |
| `has_capability(cap)` | Checks capability via position chain | authenticated |
| `manages_project(p)` | Checks if caller has managing role on project | authenticated |
| `can_edit_member(member)` | Officer/manage_members/manages_card check | authenticated |
| `can_edit_project(project)` | Leader/WG officer/admin check | authenticated |
| `is_unit_officer(unit)` | Checks officer membership | authenticated |
| `is_unit_officer_of(member)` | Checks if caller officers the member's home unit | authenticated |
| `claim_membership()` | Binds auth user to invited member | authenticated |
| `forge_member_card(...)` | Creates kind='card' member | authenticated (capability-checked internally) |
| `forge_card(...)` | Simplified card forge | authenticated (capability-checked internally) |
| `set_member_email(member, email)` | Admin email correction | authenticated (manage_members internally) |
| `person_skill_set(member, skill, level)` | Upsert skill | authenticated (can_edit_member internally) |
| `person_set_capacity(member, hours)` | Set monthly hours | authenticated (can_edit_member or review internally) |
| `member_change_submit(member, kind, value)` | Queue or apply change | authenticated |
| `member_change_decide(request, approve)` | Approve/decline change | authenticated (can_edit_member internally) |
| `member_archive(member)` | Soft-delete member (card only) | authenticated (capability-checked internally) |
| `create_project_phase1(...)` | Create project with leader slot | authenticated (any) |
| `project_rename(project, name)` | Rename | authenticated (can_edit_project internally) |
| `project_set_summary(project, summary)` | Update summary | authenticated |
| `project_set_venue(project, venue)` | Set venue | authenticated |
| `project_set_org_unit(project, unit)` | Set working group | authenticated |
| `project_set_status(project, status)` | Advance status | authenticated |
| `project_link_add(project, kind, title, url)` | Add link | authenticated |
| `project_link_remove(link)` | Remove link | authenticated |
| `project_note(project, text)` | Append history note | authenticated |
| `project_meeting_add(project, ...)` | Add meeting | authenticated |
| `project_meeting_remove(meeting)` | Remove meeting | authenticated |
| `project_archive(project)` | Soft-delete project | authenticated |
| `project_log(project, summary)` | Internal: write event | authenticated |
| `assign(need, member)` | Seat member on open need | authenticated (complex gate internally) |
| `unassign(project_member)` | Remove member from team | authenticated (can_edit_project internally) |
| `slot_close(slot)` | Close open need | authenticated |
| `work_seat(member, project)` | Predicate: can caller seat this member? | authenticated |
| `stater_mint(amt, reason)` | Mint STR to treasury | authenticated (manage_stater internally) |
| `stater_grant(target, amt, reason)` | Grant STR to member | authenticated (manage_stater internally) |
| `issue_monthly_allowance()` | Batch allowance to active members | authenticated (manage_stater internally) |
| `release_recipients(audience)` | Returns emailable members | authenticated (manage_members internally) |
| `member_capacity_all()` | Returns all members' hours+committed | authenticated |
| `skill_raise_suggestions()` | Returns members ready for skill promotion | authenticated |

### Supabase Edge Functions

| Function | Purpose | Invoked from |
|---|---|---|
| `invite-member` | Forge new officer + send invite email | OfficersPanel.svelte |
| `announce-release` | Send release email to subset or all members | admin/release/+page.svelte |

### Direct PostgREST table access (no RPC intermediary)

| Table | Operations | Component | Gated by |
|---|---|---|---|
| `member` | UPDATE (affiliation, bio) | MemberDetail.svelte:saveProfile() | RLS: member_update_self |
| `project_type` | INSERT, UPDATE, DELETE | LookupEditor via admin/projects | RLS: manage_taxonomy |
| `project_status` | INSERT, UPDATE, DELETE | LookupEditor | RLS: manage_taxonomy |
| `project_role` | INSERT, UPDATE, DELETE | LookupEditor | RLS: manage_taxonomy |
| `venue` | INSERT, UPDATE, DELETE | LookupEditor | RLS: manage_taxonomy |
| `skill` | INSERT, UPDATE, DELETE | LookupEditor | RLS: manage_taxonomy |
| `milestone_catalog` | INSERT, UPDATE, DELETE | LookupEditor | RLS: (manage_taxonomy assumed) |
| `resource_type` | INSERT, UPDATE, DELETE | LookupEditor | RLS: (manage_resources assumed) |
| `position_capability` | INSERT, DELETE | PermissionsPanel.svelte | RLS: manage_members |
| `stater_policy` | UPDATE | StrEconomyPanel.svelte | RLS: (manage_stater assumed) |
| `stater_skill_rate` | UPDATE | StrEconomyPanel.svelte | RLS: (manage_stater assumed) |

---

## 18. Data Integrity Risks

### HIGH severity

**H1. `member_update_self` RLS policy is over-permissive**  
`policies.sql:77–78`: `using (auth_user_id = auth.uid()) with check (auth_user_id = auth.uid())` permits a member to update **any column** on their own row via direct PostgREST, including `auth_user_id`, `email`, `kind`, `status`, `archived_at`, `home_unit_id`. This is a privilege escalation risk:
- A member could set their own `status = 'active'` without going through the invite flow.
- A member could change `kind` to 'card', removing their login ability (DoS on own account).
- A member could change `email` to a different address, breaking their identity.
- Theoretically, if `auth_user_id` can be set to another user's UUID, it could enable account takeover (constrained by the `unique` constraint but still a concern).

**H2. `LookupEditor` deletes taxonomy items without cascade check**  
`src/lib/LookupEditor.svelte:56–61`: `.delete().eq('id', id)` on taxonomy tables. If a `project_type` or `project_status` is deleted while referenced by existing projects, PostgREST will return a FK violation error — but this error message is surfaced raw in the UI and the user can retry. No pre-flight check warns the user that projects reference the item before deletion.

### MEDIUM severity

**M1. `project.links` jsonb column coexists with `project_link` table**  
Data written to `project.links` (jsonb) by any legacy code path is permanently invisible to the frontend. If production data has values in this column, it is silently ignored.

**M2. Orphaned `member.availability` field**  
`member.availability` defaults to `'looking'` but is never updated. All production members show as `'looking'` regardless of actual availability, making this field meaningless. If any external system reads this field, it will receive stale data.

**M3. Mock `kind: 'member'` violates DB constraint**  
Any test that verifies behavior conditional on `kind === 'member'` exercises an impossible production state. Test results for permission-gated flows involving member kind may not reflect production behavior.

**M4. No maximum value enforcement on `monthly_hours`**  
`person_set_capacity()` accepts any integer. The `member_capacity_all()` view derives free capacity as `monthly_hours - committed`. A very large hours value could make a member appear infinitely available.

**M5. `project_set_status()` allows status reversion**  
No guard prevents setting status back to a prior pipeline stage. A project can be cycled from "Finished" back to "In Progress" without data cleanup of settlement records.

### LOW severity

**L1. History/event log has no deletion mechanism**  
`project_event` records are append-only (correct by design) but there is no admin UI to correct erroneous entries. A miscreant note cannot be removed without direct DB access.

**L2. `project_meeting_remove` / `project_link_remove` bypass the confirm dialog**  
Unlike team member removal (which uses the confirm gate), removing meetings and links from a project has no confirmation step. These actions are logged in `project_event` (recoverable by re-reading history) but the action itself is irreversible in the UI.

**L3. `create_project_phase1()` cannot be rolled back from the UI**  
Once created, a project can only be archived (soft-deleted), not hard-deleted. The archive is permanent from the UI perspective.

---

## 19. File and Image Management Audit

### Avatar upload
- `member.avatar_url` (text) exists in the schema.
- No upload UI exists anywhere in the application.
- Avatars are displayed when the URL is set (presumably seeded or set via direct DB access), but the field cannot be updated through the application.
- No Supabase Storage bucket interaction was found in the frontend code.

### Project / resource attachments
- No file attachment capability exists for projects or resources.
- Links (URLs) can be added to projects via `project_link_add`, but these are external references, not hosted files.

### Resource forge images / models
- `gpu_model` and `api_model` tables store resource metadata; no image upload is associated.

**Conclusion:** The application has no file upload infrastructure. `avatar_url` is a placeholder that cannot be populated through the UI. This is a complete gap if profile photos are intended.

---

## 20. Known Defects and Broken Flows (Ranked by Severity)

| ID | Severity | Description | Location |
|---|---|---|---|
| D1 | Critical | `member_update_self` RLS allows updating any member column, including auth-critical fields | `policies.sql:77–78` |
| D2 | High | 54/60 e2e tests fail — root cause in mock-mode app startup or smoke route; cascades to all workflow tests | `tests/e2e/smoke.spec.ts:18` |
| D3 | High | `member.kind` constraint mismatch: mock uses `'member'`, DB requires `'operator'\|'card'` | `src/lib/mock-supabase.ts:29–35` |
| D4 | High | `member_archive()` only works on `kind='card'` members — active community members (`kind='operator'`) cannot be archived or removed | `20260615010000_archive_close.sql` |
| D5 | Medium | `project.type_id` cannot be changed after creation — no `project_set_type` RPC or UI | Missing RPC |
| D6 | Medium | `member.links` (scholar, hf, github, homepage) has no create/update/delete UI | `src/lib/MemberDetail.svelte:340–342` |
| D7 | Medium | `member.full_name` cannot be edited after creation — no `member_rename` RPC | Missing RPC |
| D8 | Medium | `member.availability` field is completely orphaned — never read, displayed, or updatable | `schema.sql:22` |
| D9 | Medium | `project.links` jsonb legacy column coexists with `project_link` table, never queried | `schema.sql:78` |
| D10 | Medium | LookupEditor allows taxonomy deletion without confirming cascade impact | `src/lib/LookupEditor.svelte:56–61` |
| D11 | Medium | `project.deadline` has no direct edit UI; only inheritable from venue | `ProjectCardBody.svelte` |
| D12 | Low | `project.emoji` and `project.code` columns exist but no UI or RPCs | Multiple migrations |
| D13 | Low | `member.avatar_url` displayed but no upload mechanism exists | `src/lib/MemberDetail.svelte` |
| D14 | Low | Positions can only be granted to new members at invite time — no UI to add/change positions for existing members | `src/lib/admin/access/OfficersPanel.svelte` |
| D15 | Low | `project_insert` RLS policy misleadingly requires `edit_any_project` for direct insert, but `create_project_phase1()` is open to all authenticated users | `policies.sql:103–104` |
| D16 | Low | Duplicate i18n keys in Chinese translation block of `messages.ts` (build warning) | `src/lib/messages.ts` |
| D17 | Low | Meetings and links can be removed from projects without a confirm dialog | `ProjectCardBody.svelte` |
| D18 | Low | `member.is_release_reviewer` flag has no UI (neither display nor toggle) | `src/lib/mock-supabase.ts:30` |
| D19 | Low | `person_set_capacity()` accepts unbounded `monthly_hours` value | `20260606020000` |
| D20 | Low | `member_change_submit()` change request queue has no delete/withdraw UI for pending requests (member cannot cancel their own pending change) | `src/lib/people/SkillCapacity.svelte` |

---

## 21. Missing Capabilities (Features Implied by the Model but Absent from the UI)

| Feature | Model support | UI status | Notes |
|---|---|---|---|
| Upload member avatar | `member.avatar_url` column + Supabase Storage available | ❌ No UI | Column exists; no storage bucket code found |
| Edit member links (scholar, hf, github, homepage) | `member.links` jsonb | ❌ No UI | Read-only display only |
| Edit member full name | No RPC | ❌ No RPC or UI | Would need `member_rename()` RPC + capability check |
| Set member availability status | `member.availability` ('looking'\|'limited'\|'full') | ❌ No UI anywhere | Column exists, never used |
| Toggle `is_release_reviewer` | `member.is_release_reviewer` | ❌ No UI | No migration found for this column either |
| Change member's home chapter | `member.home_unit_id` FK | ❌ No UI | Would need a transfer RPC |
| Add/remove position for existing member | `member_position` table | ❌ No UI (only at invite) | Would require OfficersPanel rework |
| Archive/offboard full `kind='operator'` member | `member_archive()` | ❌ Blocked — RPC rejects non-card members | Would need RPC extension |
| Change project type after creation | `project.type_id` | ❌ No RPC | Would need `project_set_type()` RPC |
| Direct edit of project deadline | `project.deadline` | ❌ No UI | Only inherited from venue |
| Set project emoji and code | `project.emoji`, `project.code` | ❌ No UI | Columns exist in migrations |
| Remove member from org unit / leave WG | `org_unit_member.ended_on` | ❌ No UI | `ended_on` can only be set via direct DB |
| Withdraw a pending change request | `member_change_request` | ❌ No delete flow | Member cannot cancel a pending request |
| Edit an existing project meeting | `project_meeting` | ❌ No update flow | Must remove + re-add |
| Change a team member's role within a project | `project_member.project_role_id` | ❌ No UI | Must remove + re-add |
| Hard-delete a project | `project` with `edit_any_project` RLS | ❌ No UI (soft-delete only) | RLS policy allows hard delete for admins |
| Leaderboard / community standings | `Leaderboard.svelte` exists | ❌ Component is dead; route at `/community` shows directory instead | |
| Skill endorsement | `skill_endorsement` table + RLS | ❌ No UI | Table and policies exist |

---

## 22. Test Coverage Gaps

### Untested CRUD flows

| Flow | Why untested |
|---|---|
| Create a member card (`forge_member_card`) | No e2e test for People creation path |
| Edit member affiliation/bio (self) | No e2e test for profile self-edit |
| Edit member links | Not possible — UI doesn't exist |
| Member change request approval flow end-to-end | J3.2 exists but was failing in both runs |
| Archive a card member (and verify it disappears) | No test |
| Create a project type/status/role (admin taxonomy) | No test |
| Delete a taxonomy item (cascade risk) | No test |
| Admin STR mint / grant | No test |
| Org unit application approve/decline | No test |
| Resource forge + approve flow end-to-end | RES1 was failing |
| Settlement flow (project finish → STR payout) | WF5 was failing |

### Test infrastructure issues

1. **Mock kind mismatch (D3)** — All mock members use `kind: 'member'` which is invalid. Tests that check `kind`-gated behavior (e.g., member archive, officer seating scope) may pass in mock but fail on production.

2. **SMOKE test failure** — The SMOKE test (`smoke.spec.ts:18`) was failing in both runs. Since many workflow tests start with `asRole()` and navigate the app, any layout-level failure would cascade. The root cause of the smoke failure should be the first thing investigated.

3. **No unit or integration tests** — The entire test suite is Playwright e2e. There are no unit tests for RPCs, no integration tests against a real Supabase staging database, and no `typecheck` or `lint` scripts in `package.json`.

4. **No tests for admin panels** — Economy, STR, permissions, forge queue, release notes, org units — none have test coverage.

5. **No regression tests for the bipartite staffing rule** — WGP7 tests that Assign is routed to the chapter officer (passing), but there is no test for the negative case: a WG officer attempting direct assignment.

---

## 23. Findings Summary Table

| # | Category | Severity | Finding |
|---|---|---|---|
| F1 | Security | Critical | `member_update_self` RLS policy allows updating any column including auth-critical fields |
| F2 | Testing | High | 54/60 e2e tests fail; smoke test fails indicating systemic mock-mode issue |
| F3 | Schema | High | Mock uses `kind: 'member'`; DB constraint is `'operator'\|'card'` |
| F4 | CRUD gap | High | `kind='operator'` members cannot be archived — `member_archive()` blocks non-card |
| F5 | CRUD gap | Medium | `project.type_id` not editable after creation — no RPC exists |
| F6 | CRUD gap | Medium | `member.links` (profile URLs) — no create/update/delete UI |
| F7 | CRUD gap | Medium | `member.full_name` not editable after creation — no RPC exists |
| F8 | Schema | Medium | `member.availability` completely orphaned — not read or displayed anywhere |
| F9 | Schema | Medium | `project.links` jsonb legacy column coexists silently with `project_link` table |
| F10 | Security | Medium | LookupEditor deletes taxonomy items without confirming active references |
| F11 | CRUD gap | Medium | `project.deadline` has no direct edit input |
| F12 | Dead code | Low | 9 Svelte components unreachable from any route (GettingStarted, StartHere, MiningCockpit, Leaderboard, CardBinder, MatchConsole, MemberCard, SlotBoard, SlotSeater) |
| F13 | Dead code | Low | 4 DB tables have schema + RLS but no frontend: `open_need`, `need_application`, `member_skill`, `skill_endorsement` |
| F14 | CRUD gap | Low | `project.emoji`, `project.code` — columns with no UI or RPCs |
| F15 | CRUD gap | Low | `member.avatar_url` — displayed but no upload mechanism |
| F16 | CRUD gap | Low | Position grants only available at invite time — no UI to modify existing member positions |
| F17 | Schema | Low | `project_insert` RLS policy misleadingly requires `edit_any_project` but RPC bypasses it |
| F18 | Schema | Low | `session.ts` Member type is missing 7 fields present in the DB |
| F19 | i18n | Low | Duplicate translation keys in `messages.ts` Chinese block (build warning) |
| F20 | UX | Low | No confirm before deleting taxonomy items, meetings, or links |
| F21 | CRUD gap | Low | Member change request cannot be withdrawn by the member |
| F22 | CRUD gap | Low | Meeting edit: no update flow, must remove and re-add |
| F23 | CRUD gap | Low | Project team member role cannot be changed — must remove + re-add |
| F24 | Validation | Low | `project_link_add()` silently prepends `https://` to scheme-less URLs |
| F25 | Validation | Low | `person_set_capacity()` has no maximum cap on `monthly_hours` |
| F26 | CRUD gap | Low | `member.is_release_reviewer` flag — no UI display or toggle |
| F27 | Auth | Low | Auth user with no matching member row gets empty app rather than an error |

---

## 24. Recommendations (Audit-Only — Implementation Not In Scope)

These recommendations are ordered by risk and impact. Implementation is outside the scope of this audit.

### Critical

**R1 — Restrict `member_update_self` to safe columns only**  
Replace the broad `UPDATE` policy with one that explicitly permits only `affiliation`, `bio`, and `avatar_url`. Any column that controls identity (`auth_user_id`), account state (`status`, `archived_at`), or role (`kind`, `home_unit_id`) should require the `manage_members` capability.

### High

**R2 — Investigate and fix the e2e smoke test failure**  
The SMOKE test failure blocks all 54 other tests. Identify why client-side navigation is crashing and fix the root cause in the mock app. Once SMOKE passes, the true pass/fail rate of the workflow tests will become clear.

**R3 — Fix mock `member.kind` to use `'operator'`**  
Change all `kind: 'member'` values in `mock-supabase.ts` to `kind: 'operator'` to match the DB constraint. This will make mock-mode tests exercise the same code paths as production.

**R4 — Extend `member_archive()` to cover `kind='operator'`**  
Add an offboarding path for claimed members (set `auth_user_id = null`, `status = 'archived'`, `archived_at = now()`). Gate appropriately on `manage_members`. Document what happens to their open commitments and STR balance on archive.

### Medium

**R5 — Add `project_set_type()` RPC and UI**  
A project's type is a fundamental attribute that users may need to correct. Add the RPC (gated by `can_edit_project`) and an InlineField in ProjectCardBody.

**R6 — Add member links editor**  
Add a UI section in MemberDetail to add/edit/remove `links.scholar`, `links.hf`, `links.github`, `links.homepage`. These can use a direct `UPDATE` gated by `member_update_self` once the RLS policy is scoped (R1).

**R7 — Add `member_rename()` RPC and UI (officer/admin only)**  
`full_name` needs to be correctable for typos and legal name changes. Gate on `manage_members` or `can_edit_member`.

**R8 — Drop or migrate `member.availability` and `project.links` orphaned columns**  
Either implement the `member.availability` feature (add a UI selector for 'looking'/'limited'/'full') or remove the column. For `project.links` jsonb: write a migration that copies any non-empty data to `project_link` rows, then drops the column.

**R9 — Add cascade pre-flight check to LookupEditor**  
Before deleting a taxonomy item, query for projects/members that reference it. Show a count and require explicit confirmation if references exist.

### Low

**R10 — Scope `project_insert` RLS to reflect actual business rules**  
Change the `project_insert` policy to `with check (true)` (any authenticated user) or add a new capability like `create_project`. The current mismatch between RLS and RPC semantics is misleading.

**R11 — Add a `typecheck` script to `package.json`**  
`"typecheck": "svelte-kit sync && svelte-check --tsconfig ./tsconfig.json"` so type errors are caught in CI without requiring a full build.

**R12 — Widen `session.ts` Member type**  
Include all fields needed by the layout and permission checks to avoid double-fetching the member record on every profile page load.

**R13 — Add `member.availability` UI or remove the column**  
The current situation (column exists, always `'looking'`, invisible) produces misleading data.

**R14 — Audit `is_release_reviewer` — add migration if intentional**  
This field appears in the mock but no migration creates it. Either add a migration and a toggle UI, or remove it from the mock.

---

## 25. Appendices

### Appendix A — File inventory

**Active routes (reachable from navigation)**

| Route | Surface | Auth required |
|---|---|---|
| `/login` | Magic-link login | No |
| `/projects` | Project list + create | Yes |
| `/projects/[id]` | Project detail | Yes |
| `/people` | People roster | Yes |
| `/members/[id]` | Member profile | Yes |
| `/members` | Members list (thin route) | Yes |
| `/profile` | Self-profile shortcut | Yes |
| `/my` | My tasks | Yes |
| `/wallet` | STR wallet | Yes |
| `/community` | Directory | Yes |
| `/units` | Org units list | Yes |
| `/units/[id]` | Org unit detail | Yes |
| `/guide` | Role guide | Yes |
| `/opportunities` | Open needs browse | Yes |
| `/str` | STR overview | Yes |
| `/officer` | Officer hub | Yes |
| `/officer/chapter/[id]` | Chapter officer view | Yes |
| `/officer/wg/[id]` | WG officer view | Yes |
| `/admin` | Admin home | Yes (admin cap) |
| `/admin/economy` | STR + resources | Yes |
| `/admin/forge-queue` | Forge review queue | Yes |
| `/admin/review` | Member change review | Yes |
| `/admin/projects` | Project taxonomy | Yes |
| `/admin/guild` | Skills + leader reqs | Yes |
| `/admin/access` | Officers + permissions | Yes |
| `/admin/org-units` | Org unit management | Yes |
| `/admin/release` | Release email | Yes |
| `/admin/writing` | Writing taxonomy | Yes |
| `/admin/skills` | Skill list | Yes |
| `/admin/statuses` | Status list | Yes |
| `/admin/types` | Type list | Yes |
| `/admin/venues` | Venue list | Yes |
| `/admin/roles` | Role list | Yes |
| `/admin/invites` | Invite management | Yes |
| `/admin/stater` | STR admin | Yes |
| `/admin/milestone-catalog` | Milestone catalog | Yes |
| `/admin/resource-types` | Resource types | Yes |
| `/admin/resources` | Community resources | Yes |
| `/admin/positions` | Position management | Yes |
| `/styleguide` | Component gallery | Yes |

**Dead / unreachable components**

| File | Dead since |
|---|---|
| `src/lib/GettingStarted.svelte` | Phase 2 pivot to structured onboarding |
| `src/lib/StartHere.svelte` | Phase 2 pivot |
| `src/lib/MiningCockpit.svelte` | Mining concept removed |
| `src/lib/Leaderboard.svelte` | Leaderboard page removed |
| `src/lib/cards/CardBinder.svelte` | Card binding flow removed |
| `src/lib/cards/MatchConsole.svelte` | Moved to MatchBoard |
| `src/lib/cards/MemberCard.svelte` | Only used by CardBinder (dead) |
| `src/lib/cards/SlotBoard.svelte` | Slot UI replaced by ProjectTeam |
| `src/lib/cards/SlotSeater.svelte` | Replaced by MatchBoard/assign RPC pattern |

### Appendix B — Migration timeline summary

67 migrations from `20260601173600` to `20260726020000`. Key structural changes:

| Migration | What changed |
|---|---|
| 20260601173600 | Project org_unit FK |
| 20260602012918 | assign() RPC first version |
| 20260603040000 | Project card RPCs (rename, summary, venue, links, meetings, history) |
| 20260603310000 | create_project_phase1() |
| 20260606010000 | Task living record (project_task) |
| 20260606020000 | person_skill, monthly_hours, skill RPCs |
| 20260615010000 | archived_at on member + project; archive RPCs |
| 20260615030000 | member_change_request review queue |
| 20260615040000 | Officer can edit chapter members (can_edit_member extension) |
| 20260726010000 | Task owner can update own task state (G3 rule) |
| 20260726020000 | Bipartite assign fix: outer gate matches work_seat() exactly |

### Appendix C — Capabilities reference

| Key | Description |
|---|---|
| `manage_members` | Add, edit, archive any member |
| `invite_members` | Create and send invites |
| `manage_taxonomy` | Edit types, statuses, roles, skills, venues |
| `edit_any_project` | Edit any project (not just managed ones) |
| `manage_stater` | Mint, grant, adjust STR balances |
| `manage_resources` | Approve and edit resource forge requests |
| `review_skillcard` | Approve skill card submissions |
| `manages_card` | Manage cards in own chapter (officer-level) |
| `manage_units` | Manage org unit structure |

### Appendix D — Test run raw results

Run 1 (background process `butuk0uhb`):
- 54 failed, 6 passed, duration 6.8m

Run 2 (earlier background process `br6r5qv0v`):
- Same 54 failing, same 6 passing (consistent results across two independent runs)

Passing tests across both runs:
1. `adversarial.spec.ts:89` — A6 (double-click): double-clicking Save does not corrupt the value
2. `adversarial.spec.ts:110` — A8 (stale across surfaces): lowering available time updates matcher's free capacity
3. `adversarial.spec.ts:134` — A9 (cold start): empty community orients the newcomer
4. `concepts.spec.ts:32` — M3 (custodial cards): the "card" concept is explained VISIBLY
5. `wg-project.spec.ts:82` — WGP5 (#51): a plain member creates a project and can still see it afterwards
6. `wg-project.spec.ts:133` — WGP7 (#53-A): a WG leader sees candidates but Assign is routed to the chapter officer

---

*End of audit. Document is limited to this file (`audit.md`). No production code was modified.*
