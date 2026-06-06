# Interaction Detail — every page, every interaction (as-is)

*The complete interaction reference. Organized **by page**; under each page, **every** interactive
element (button · link · tab · toggle · input · select · level-pip) is written out: what the user
does, the exact label, what appears/changes, the guard/disabled condition, the function + RPC it
fires, validation rules, branches, and what the user sees afterward.*

**Roles referenced:** P = President/admin · C = Chapter officer (people + matching) · W = Working-Group
officer (projects) · L = project leader · R = member · me = self. Capability keys map to named groups
(`manage_members`, `edit_any_project`, `manage_resources`, `manage_stater`, `review_skillcard`,
`mint_skillcard`, `manage_taxonomy`).

---

# 1. Login (`/login`)

*Invite-only OTP wall. Reached directly, or bounced here by the route guard when a signed-out user
hits any gated route.*

### Email input
- **Do:** Type the invited email. Pre-filled from `?email=` if the invite link carried it.
- **Calls:** none on type; bound to `email`.
- **Validation:** `type=email`, `required`.

### Send verification code (button) → "Sending…"
- **Do:** Click (or Enter) to request the code.
- **Guard / disabled when:** `disabled={loading}`; label flips to "Sending…".
- **Calls:** `signIn()` → RPC `is_email_invited({ p_email })`; if invited → `supabase.auth.signInWithOtp({ email, options: { shouldCreateUser: true } })` (emails a 6-digit code, no magic link; `shouldCreateUser:true` lets a first-time invited member get an auth row).
- **Branches:**
  - `!supabaseConfigured` → "Supabase is not configured yet.", no network.
  - `is_email_invited` returns false → **"This email isn't on the invite list. Ask a community admin to invite you first."** — no code sent, no signup (this is the signup-blocked path).
  - RPC/auth error → raw message shown, stays on email form.
  - Success → `sent=true`, form swaps to the code form.

### Code input
- **Do:** Type/paste the 6-digit code. `inputmode=numeric`, `autocomplete=one-time-code`, `maxlength=10`.
- **Calls:** none on type; bound to `code`.

### Verify & sign in (button) → "Verifying…"
- **Do:** Click to verify.
- **Guard / disabled when:** `disabled={verifying}`; label flips to "Verifying…".
- **Calls:** `verify()` → guard `code.trim().length >= 6` (else "Enter the code from your email."); then `supabase.auth.verifyOtp({ email, token, type: 'email' })`.
- **Branches:** wrong/expired → "That code is invalid or has expired. Request a new one." (stays on code form). Success → session established; the layout's `onAuthStateChange` runs `claim_membership` + `loadProfile`, and the route guard redirects off `/login` to `/`.

### Use a different email (button)
- **Do:** Click to go back to the email form.
- **Calls:** `restart()` → `sent=false`, `code=''`, `error=''` (email retained).

**Auth-error bounce:** if a magic link was expired/already-consumed, `captureAuthError()` in the layout
parses `error_code`/`error_description` from the URL, sets `$authError` (special copy for `otp_expired`),
strips the params, and the `/login` page shows that reason above the form.

**Post-login / unclaimed-card block:** after `verifyOtp`, `onAuthStateChange` fires `claim_membership`
(binds the invited `member` row to `auth.uid()` by email) then `loadProfile`. If the signed-in email has
**no** member row, the app shows a banner *"You're signed in as {email}, but this email isn't linked to a
membership… ask an admin to invite you"* with a link to `/guide`; every data page renders empty.

**Backend:** RPC `is_email_invited`, `claim_membership`; Auth `signInWithOtp` / `verifyOtp` / `signOut`.

---

# 2. Global shell (sidebar · topbar · footer — every page)

*Renders only when a session exists.*

### Sidebar nav links
- **Home** (`/`) — active on exact `/`.
- **Projects** (`/projects`) — active on prefix.
- **Console** (`/officer`) — **only shown if** `$officerUnits.length > 0` OR `canAdmin` (`manage_taxonomy`/`manage_members`/`edit_any_project`).
- **Community** (`/community`).
- **Guide** (`/guide`).
- **Admin** (`/admin`) — **only shown if** `canAdmin || canApprove` (officer, or holds resources/stater/members/skillcard review).
- **Do:** click → SvelteKit navigation. Non-officer plain members see only Home/Projects/Community/Guide.

### Wallet chip — "Net value" (link → `/wallet`)
- **Shows:** `(liquid + nominal)` STR via `loadBalance` (`stater_balance.balance` + Σ `stater_project_member_nominal.nominal`). "0 STR" when no member.
- **Do:** click → `/wallet`.

### Avatar / account menu (button)
- **Do:** click the footer identity (initials + name + email) → toggles `menuOpen`.
- **Menu items:** **Overview** → `go('/')` · **My profile** → `go('/members/{id}')` (fallback `/profile`) · **Sign out** → `signOut()` → `supabase.auth.signOut()` → `/login`.
- **Close:** backdrop click or selecting any item.

### Theme toggle (button)
- **Do:** click ☀/☾ → `toggleTheme()` flips the persisted `theme` store. Cosmetic.

### Language switcher
- **Do:** change language → all `$t(...)` strings re-render. (No "act-as"/impersonation switcher exists.)

**Route guard:** signed-out + non-`/login` non-`/guide` → bounced to `/login`; signed-in on `/login` → bounced to `/`.

---

# 3. Home (`/`)

*Identity header + cockpit + accepted-apps digest + badges. Loaders run once a `$member` exists.*

### Header (display) + Guide ↗ (link)
- Shows avatar initials, first name (or "Overview"), affiliation/email. Role pills: "Officer · {unit}" if an officer; warn pill "Community steward" if `canAdmin||canApprove`. "Guide ↗" → `/guide`.

## Mining Cockpit (the hero)

### STR ring + status line (display)
- Conic ring filled to `claimablePct = round(liquid/(liquid+nominal)*100)`; center = `<CountUp>` liquid + "claimable STR"; beside it "+{nominal} accruing in projects".
- **`statusLine` branches:** no projects → "You're not on a project yet…"; else "Contributing ≈{rate}/mo across {n} projects" + " · {n} ready to settle" if any settleable.

### Next-best-action (single CTA button/link)
- **Priority order (only one shows):**
  1. Any settleable project I lead → **"Settle {name}"** → `/projects/{id}` (solid).
  2. Else chapter officer with free-time members → **"Assign {n} collaborators with free time"** → `/officer/{chapter}` (solid).
  3. Else zero projects → **"Find a project to join"** → `/projects` (ghost).
  4. Else → no button, shows "✓ All your projects are on track."
- **Settleable** = I'm leader, project finished, and not already in a `submitted`/`under_review`/`approved` settlement.

### Your projects grid (links)
- Each → `/projects/{id}`; `hot` when settleable. Shows name, "Ready to settle"/status, "First author"/"Contributor" + "{myNominal} contributed".

### Your team strip (link) — only if I officer a chapter with members
- → `/officer/{chapter}`; "Your team: {n} collaborators · {free} with free time this month · Open console →".

## Accepted-applications digest
- **Shows** when I have `accepted` applications: "{n} application accepted — confirm to join". First 3 → chip link "{project} →" → `/projects/{id}` (confirm there).

## My badges
- "Badge catalog →" → `/community?tab=badges`. States: loading / "No badges yet…" / certified `<Medal>` chips / "Skills awaiting a badge" dim chips.

### Manage link
- **"Manage your resources & profile →"** → `/members/{my id}`.

## Start Here panel (role-aware, dismissable)
- Steps by role: chapter → "Add your people" / "Put them on projects" (→ `/officer/{chapter}`); WG → "Create or claim a project" / "Post what it needs"; neither → "Explore projects"; approver → append "Approve what's waiting" (→ `/admin/forge-queue`).
- **✕ hide** → `dismissed=true`, persisted in `localStorage('startHidden')`.

**Backend:** `project_member`, `need_application`, `open_need`, `project`, `stater_balance`, `work_commitment`, `stater_settlement`, `member`, `resource`, `skill`, `member_skill`, `stater_project_member_nominal`, `stater_ledger`.

---

# 4. Projects — list & create (`/projects`)

### Start a project / Cancel (button)
- **Do:** toggles `showForm` (label flips). **Guard:** only rendered if `$member`.

### Create-project form (opens at status "Proposal")
- **Name *** (input) — required (`Name and type are required.`).
- **Type *** (select) — required; first option `—`. Drives `leaderStake` (unused in P1, free).
- **Target venue** (select) — optional; options show `· ddl {date}` when set.
- **Working Group** (select) — only rendered if WGs exist; optional. **If set → after create, redirect to `/officer/{wg}`** (hand-off to slot board).
- **Proposal link *** (input) — required (`A proposal link is required…`); auto-prefixes `https://`.
- **Summary** (textarea) — optional.
- **Create project / Creating… (button):** `disabled={creating}`. `createProject()` → RPC `create_project_phase1({ p_name, p_type_id, p_status_id, p_wg_unit, p_summary, p_venue_id, p_proposal_url })` — **free, no bond, no auto leader-seat** (first-author seat stays open).
  - **Branches:** validation fail → `error`, no RPC; RPC error → `error`, form stays; success → clears fields, `showForm=false`, reload grid; if WG set → full redirect to `/officer/{wg}`.

### Filter / search / sort toolbar
- **Status chips:** "All" (`statusFilter=''`) + one per status. Picking a status **overrides the default in-play filter** (e.g. surfaces `Hold`). Toggle off by re-click.
- **Search** (input) — live filter over name/leader/group/venue/type.
- **All types** (select) — filter by type.
- **All venues** (select) — grouped by venue kind; `kind:{k}` matches a whole kind.
- **Reset** (button) — only shown when any filter active; clears all four.
- **Sort by** (select) — Deadline / Nominal pool / Seats / Open needs / Name.
- **Sort direction** (button ▲/▼) — flips `sortDir`.

### Project card (EntityCard, button)
- **Do:** click → `openProject(r)` → opens quick-view drawer. Claimable projects (no leader, not finished) show "lead open" amber status.

### Hall of fame (collapsible)
- Header (button/Enter/Space) toggles `showHof`; shows "{n} shipped · {n} STR minted". Cards (button) → `openProject`.

### Quick-view drawer
- **Open full page →** (link) → `/projects/{id}`.
- Body = `<ProjectDetailBody showHeader={false}>` (all detail interactions below apply in-drawer too). Close → `sel=null`.

---

# 5. Project detail (`/projects/[id]` and the drawer)

*`ProjectDetailBody` + `ProjectCardBody` + `ProjectSlotCard` + `SlotSeater` + `SettlementForm`.
Permissions: `canSeat` = manage_members/edit_any_project/any-officer · `canManage` = edit_any_project
or officer of the project's WG · `canPostNeed` = canManage OR I'm the leader · `canEdit` (card edits) =
RPC `can_edit_project` (leader / WG officer / admin).*

### Header / stats / STR pipeline (display)
- Title, claimable pill, type, deadline chip. Stats: Nominal pool, Seats filled/total, Open needs, milestone `×mult` (when >1), first author.
- **STR pipeline stepper** (not clickable): `Accruing → Finish → Settling → Settled`. Stage from `settleStatus`/`finished`. Projected payout = `round(pool × mult)`. Note text varies by stage and whether you can settle.

### ＋ Post a need (button)
- **Guard:** only when `canPostNeed && !finished`. Toggles `showPostNeed` → `<ResourceForgeForm mode="need">` (see §10). On forge → closes + reloads.

## Seat a member (SlotSeater) — only when `canSeat && !finished`
- **Candidate pool by role:** admin → all members; chapter officer → cards in their chapter units; else → only self. (`work_seat` re-checks server-side.)
- **Slot row (button — openPicker):** click an open slot → reveals search + candidates; presets `amount = quota ?? (leader?20:0)`.
- **Search** (input) — filter candidates by name.
- **Candidate card (button — pickCard):** `disabled={!q.ok}`. **`qualify` rules:** skill badge `rank ≥ req_access` (else "needs {level}"); resource slots need a matching held resource (else "no matching resource"); capacity via `remainingFor` (labor/leader use `usedHoursByMember` vs `monthly_quota`; other resources use `usedByRes`) → "No capacity left this month" / "Only {n} left — need {q}".
- **Monthly amount / Monthly writing hours** (input) — `over` when `amt > remaining`; `under` when `amt<=0` or below need quota; red border + inline reason.
- **Resource** (select) — only for `work_resource` slots; required.
- **Seat (button):** `disabled` if busy OR over OR under OR (resource slot && no `resId`). `seat()` → RPC `work_seat({ p_slot, p_member, p_resource, p_year_month, p_monthly_amount, p_as })`. Success → reload, slot count increments.

### ＋ Add directly (admin-only — SlotSeater) 
- **Guard:** only when `isAdmin` (manage_members/edit_any_project).
- **daOpen toggle** → search (daQ) → **member card (daMember)** → **Kind toggle Labor/Resource (daKind)**.
  - **Labor:** Skill (daSkill, required), Level (daLevel), Monthly hours (daHours).
  - **Resource:** Resource type (daResType), Resource (daResource, required) — if member holds none of that type, shows **"Add it on their card →"** link → `/members/{daMember}` (new tab).
- **Create & seat (button):** `disabled={daBusy}`. `seatDirect()` → RPC `seat_direct({ p_project, p_member, p_slot_kind, p_skill, p_req_access, p_resource_type, p_resource, p_year_month, p_monthly_amount })` — forges a bespoke slot and seats in one step. Validation: member required; labor→skill required; resource→resource required.

### Manage in slot board / Open slot board → (link)
- Only when `g.wgUnitId` set → `/officer/{wg}`. Solid label if `canManage`, else ghost.

### Release claim / Releasing… (button)
- Only when `canManage`; `disabled={releasing}`. `releaseClaim()` → RPC `release_claim({ p_project })` → leader seat reopens, reload.

## Editable project card (ProjectCardBody) — inline fields when `canEdit`
- **Summary** (inline textarea) → `project_set_summary`.
- **Target venue** (inline select) → `project_set_venue`.
- **Working Group** (inline select) → `project_set_org_unit`.
- **Name** (inline text) → `project_rename`.

### Status pipeline stepper (buttons)
- **Hold / Resume:** only when `canEdit && !finished`; `disabled` while busy. → `project_set_status` (to Hold / back to held-from).
- **Pipeline step (each status):** `clickable = canEdit && !isHold && !finished && !current && !terminal`. → `project_set_status({ p_project, p_status })`. **Finished is NOT clickable** — reached only via Mint done.
- **✓ Mint done (button):** only when `canEdit && isUnderReview`; `disabled` while busy. → RPC `forge_project_done({ p_project })` → "Completion submitted for review." (becomes Finished only after the queue approves; does not reload immediately). Before Under review, shows hint "Advance to Under review to submit completion."

### Open settlement → (button) + Settlement section
- Only when `isFinishedProj && canEdit`. Click → `showSettle=true` → `<SettlementForm>`.

### Media & links (ProjectCardBody)
- **Add link / Cancel (button):** only `canEdit`. Fields: Kind (select, default `paper`), Title, URL (required), Notes. **Add link** → `project_link_add`. Link items open in new tab. **✕ remove** → `project_link_remove` (disabled while busy).

### Meetings
- **Schedule meeting / Cancel (button):** only `canEdit`. Fields: Title (req), Starts (req datetime), Ends, Repeats (none/weekly/biweekly/monthly), Location, Agenda. **Schedule meeting** → `project_meeting_add`. **✕ remove** → `project_meeting_remove`.

### Milestones
- **Claim a milestone… (select mClaim)** + **Claim (button):** only when `canEdit && !finished`; Claim `disabled` if busy or no selection. → RPC `forge_milestone({ p_project, p_catalog })` → "Milestone claimed — pending verification." Verified milestones raise the pool + multiplier (capped ×3).

### History / notes
- **Note (input)** + **Post (button):** only `canEdit`; Post `disabled` if busy or empty. Enter or click → `project_note({ p_project, p_text })`. Timeline shows events; empty → "No activity yet."

## Settlement form (SettlementForm)
- Loads `work_commitment`, one row per contributor (default `weight = nominal`, `isAuthor = true`).
- **Weight (input per row):** drives the "Share" % column.
- **Author checkbox (per row):** toggles author; `disabled` for the leader (always first author).
- **Corresponding author (radio):** exactly one.
- **Settlement notes (textarea).**
- **Submit settlement for review (button):** `disabled={busy}`. Validation: ≥1 author, totalWeight > 0. → RPC `submit_settlement({ p, notes, items })` (items carry role/weight/author flags). → 72h review window, then STR payout. Pipeline moves Settling → Settled.
- **Cancel (button)** → closes.

**Finished gating:** when finished, Post-need / Seat / Add-directly / milestone-claim / status-clicks / Hold-Resume are all hidden; only settlement is active.

---

# 6. Officer hub (`/officer`)

- **Auto-redirect:** authReady ∧ non-admin ∧ exactly one officer unit → `goto('/officer/{unit}')` (single-unit officers skip the list).
- **Empty:** non-officer non-admin → "You are not an officer of any chapter or working group."
- **Chapter card / Working-Group card (EntityCard, button):** click → `/officer/{unit}`.
- **Review section:** "Unit applications" card → `/admin/review`; **(admin only)** "Review queue" card → `/admin/forge-queue`.

---

# 7. Officer Console (`/officer/[unitId]` — MatchConsole)

*The operator's desk. `isOfficer` = manage_members/edit_any_project or officer-of-this-unit. `isChapter`
drives the two-column matching board; WG shows a single column of read-only needs + project tools.
Header subtitle: "{Chapter|Working group} · Month {ym} · {n} open needs".*

### ＋ Add a member (button) — chapter officer
- **Do:** toggles `showForgeMember` → `<ForgeCard mode="member">`.
- **Fields:** Full name (req), Email (req), Affiliation, Monthly hours, **Skills & levels** (SkillLevelPicker → staged as one badge batch).
- **Create (button):** `disabled={busy || !valid}` (valid = name+email). `forgeMember()` → RPC `forge_member_card({ p_full_name, p_email, p_unit, p_affiliation, p_badges })`; **then if hours>0**, RPC `forge_resource(...'My time', monthly_quota=hours, unit='hour')`. Both go to **review queues**, not applied live.

### ＋ Create project (button) — WG officer
- **Fields:** Name, Type (default first), Status (default first), Summary, Proposal URL. Copy: "Phase 1 — free, no STR bond. You become its leader."
- **Create project (button):** `disabled={busy==='create'}`. Validation: name + type required. `doCreate()` → RPC `create_project_phase1(...)`.

### Claim (button) — WG officer, "Unclaimed projects" section
- **Guard:** section only when `isOfficer && !isChapter && unclaimed.length`. Per-row `disabled={busy===p.id}`.
- **Calls:** `claim(p)` → RPC `forge_claim({ p_project, p_wg_unit })` → project leaves unclaimed, joins owned.

## The matching board (chapter — two columns: Open needs ⟷ Roster)

### Guide line (`.mc-guide`, display)
- Neither selected → "Pick an open need, then seat a qualified person from your roster."
- Need selected → "Filling **{skill|kind}** · {project} — seat a highlighted candidate →" + **✕ clear** (`selNeed=null`).
- Person selected → "Placing **{name}** — pick a need they can fill →" + **✕ clear** (`selPerson=null`).

### Need row (button — pickNeed)
- **Do:** toggle-select a need. On select, presets seat `amount = quota`. Selecting re-sorts the **roster**: qualified people float up; each row shows `.fit` (green) or `.dim` (failed qualify, or hours full).

### Person row (button — pickPerson)
- **Do:** toggle-select a person; auto-selects their matching resource. Selecting re-sorts the **needs**: ones they qualify for float up.
- **Headline per person (`capOf`):** "{used}/{quota} hr used", warn "hours full" badge + `.dim` when `used >= quota`; "card" badge for card-type.

### Qualify rules (per candidate)
1. Filled (`filled >= headcount`) → "Filled".
2. Each skill req met via **badge** (`rank ≥ min_level`) **or** a held resource declaring that skill at level; else "Needs {level} {skill}".
3. Resource-type needs require a held resource of that type; else "No matching resource held".
4. Capacity via `remainingFor` (Labor → `usedHoursOf`; else `usedByRes`): `<= 0` → "No capacity left this month"; below need quota → "Only {n} left — need {q}".

### Seat → (button) → inline seat panel
- **Monthly amount (input):** label appends "· need {q}" / "· {n} left"; red `.over` when over/under.
- **Resource (select):** only when need has a resource type.
- **Confirm seat (button):** `disabled` if busy OR `seatOver` OR `seatUnder` OR (resource type required && no `resId`). Inline reasons for over/under. `seat()` → RPC `work_seat({ p_slot, p_member, p_resource, p_year_month, p_monthly_amount, p_as })` → reload; a now-full need drops off the board.

### WG variant
- Needs render as **read-only links** `→ /projects/{id}` (no roster column). Empty copy: "No open needs — take on a project or post one."

## Post a need (WG officer) — "Post need" section / drawer
- **+ Post need (button)** → `postNeedFor = p` → drawer `<ResourceForgeForm mode="need" project={p.id}>` (see §10). Labor vs resource branch; goes to review queue.

## Badges (✦) — BadgeTree drawer
- **✦ (button per roster row):** `forgeBadgeFor = p` → drawer "Badges · {name}" with `<BadgeTree canEdit>`.
- **Rank pip (4 per skill):** `disabled={!canEdit}`. `setRank` — **no downgrade** (clicking at/below current clears the stage). Staged raises show `.stage`.
- **Submit {n} for review (button):** only when changes; `disabled={busy}`. → RPC `forge_badges({ p_member, p_items, p_as })` (one batch). **Reset (button):** `draft = {...current}`.

### Set rank on slots (setRank, `disabled={!canEdit}`)
- Used in the slot-rank context; same guard.

**Backend:** `forge_member_card`, `forge_resource`, `create_project_phase1`, `forge_claim`, `work_seat`, `forge_badges`, `forge_need`; reads `org_unit`, `project_slot`, `skill`, `resource_type`, `project_type`, `project_status`, `work_commitment`, `member`, `badge`, `resource`, `project`.

---

# 8. Community (`/community`)

### Family tabs (tab) — People · Chapters · Working Groups · Badges
- **Do:** click/Enter/Space → `onTab(tk)`: sets tab, clears search, resets to Directory view.

### Directory / Standing (toggle) — when the family has standing
- Directory → card grid + search; Standing → `<Leaderboard>` (search hidden). Badges has no Standing.

### Search (input)
- Live filter (name; + code for units; + domain for badges). Directory view only.

### Person card (button → drawer)
- `openPerson(r)` → drawer = full `<MemberDetail breadcrumbs={false}>` + **Open full page →** → `/members/{id}`. (All member-card interactions in §9 apply in-drawer.)

### Unit card (button → drawer)
- `openUnit(u)` → unit drawer.
  - **Apply to join (button):** only when `!isOfficerOf(u) && status!=='active'`; `disabled` while busy or already pending. `applyUnit` → RPC `apply_to_unit({ p_unit })` → status becomes "pending", button → "Application pending". 
  - **Open officer console → (link):** only when officer/manage_members → `/officer/{u}`.

### Badge card (button → drawer) — award flow
- `canAward` = manage_members/mint_skillcard/any-officer. `isBadgeAdmin` = manage_members/mint_skillcard.
- **✦ Award this badge (button):** `openAward()` loads selectable cards — all cards (badge admin) or only the officer's chapter cards.
- **Award search (input)** — filter (cap 60 shown).
- **Award card toggle (button per member)** — `toggleAward` add/remove from `awardSel`.
- **Level (select)** — apprentice→master.
- **Submit {n} for review (button):** `disabled={awardBusy || !awardSel.size}`. `doAward` loops selected → RPC `forge_badge({ p_member, p_skill, p_level, p_as })` each; partial failures counted. → "{n} badge(s) submitted for review."
- **Cancel (button)** — closes panel.
- **Holder link** → `/members/{id}`.

---

# 9. Member card (`/members/[id]`)

*Same component renders in the Community drawer. "Tabs" are in-page anchor jumps (SectionNav):
Overview · Badges · Projects · Resources. Edit rights: `isMe` (self), `canEdit` (RPC `manages_card`,
chapter officer over a card), `canEditCatalog` = canEdit/self/manage_members/manage_resources,
`canAward` = isMe/canEdit/manage_members/mint_skillcard.*

## Self-edit panel — only when `isMe`
- **Affiliation (input)** · **Bio (textarea)** — bound to `pAffiliation`/`pBio`.
- **Save / Saving… (button):** `disabled={profileSaving}`. `saveProfile()` → `member.update({affiliation, bio})`; on success "Saved" badge + header updates live.

### External profile links (links)
- Per `mem.links` entry (Scholar/HF/GitHub/Homepage) → new tab.

## Resources tab (`#resources`)
- **Editable (when `canEditCatalog`):** embeds `<ResourceForgeForm holder={id} scope="member" editId={editResId}>` (see §10) — this is how "My time" labor hours and every resource are declared/edited. Note: "⏳ New resources are reviewed by a steward before they can be offered."
  - Catalog table rows show Name/Type/Capacity/Availability/Review-status (`✓ approved`/`✕ rejected`/`⏳ pending`).
  - **Edit (button per row):** `editResId = r.id` → form loads that resource (`update_resource` on save), shows "Cancel edit" link.
  - **Cancel edit (button):** `editResId=''`.
  - **Remove (button, danger):** `removeResource` → hard `delete` from `resource` (no confirm) → reload.
- **Read-only (else):** shows only approved offerings; no controls.

## Stewarded for the community (display)
- Community-scope resources held in custody; table only, no controls.

## Overview KPIs (`#stats`, display)
- Contribution (`totalNominal`) · Badges · Projects · Resources.

## Badges (`#badges`)
- **When `canAward`:** editable `<BadgeTree canEdit>` (self-claim or officer-award) — pip stage → **Submit {n} for review** → RPC `forge_badges` (one batch); **Reset**. No-downgrade rule.
- Else: "No badges yet." or static `<Medal>` chips.

### Project row link → `/projects/{id}`.

---

# 10. ResourceForgeForm (shared: member card · console · community · project need)

*One type-adaptive form. Modes: `supply` (declare a resource), `need` (post a project need), and edit
(when `editId` set). Type's `valuation_method` morphs the fields.*

### Type (select)
- From `resource_type` (rank order). Drives every branch: `isLabour` = flat·hour; `isDescribed` = type's `described` flag; quota unit label (GPU-hours/1M tokens/USD/unit).

### Name (input) — supply only — required.
### Holder/steward (select) — supply + `holderPicker` only (hidden on member card; holder fixed).
### GPU model (select) — when `meth==='gpu'` — required (`Pick a GPU model.`).
### API model (select) — when `meth==='api'` — required (`Pick an API model.`).
### Description (textarea) — supply + described type (e.g. Datasets) — replaces quota; `quota` forced to 1.
### Quota input — when not (supply && described) — "Monthly quota"/"Quota / month" + unit hint.
### Headcount input — need mode only — min 1.
### USD / unit input — supply, flat-non-labour-non-described only.
### Skills & levels — SkillLevelPicker — when `isLabour` ("Required skills & levels" need / "Skills & level these hours can fill" supply).

### Submit (button) → "Working…"
- **Label:** "Save changes" (edit) / "Post need" (need) / "Add resource" (supply). `disabled={busy}`.
- **Calls (`forge()`):**
  - need → RPC `forge_need({ p_project, p_slot_kind: isLabour?'work_labor':'work_resource', p_req_access, p_skill, p_resource_type, p_quota, p_headcount, p_requirements })`.
  - edit → RPC `update_resource({ p_resource, p_name, p_monthly_quota, p_usd_per_unit, p_skills, p_gpu_model, p_api_model, p_details })`.
  - new supply → RPC `forge_resource({ p_type, p_name, p_holder, p_scope, p_monthly_quota, p_usd_per_unit, p_skills, p_gpu_model, p_api_model, p_details })`.
- **Validation:** need → type required, labour needs ≥1 skill; supply/edit → type+name+holder (unless edit), gpu/api model when applicable.
- **After:** "…submitted for review." / "Saved — re-submitted for review." / "Resource forged — pending review."; resets; `onForged()` fires (member card clears `editResId` + reloads → row reappears `⏳ pending`).

## SkillLevelPicker (sub-component)
- Leaf skills grouped by domain; 4 pips A/J/C/M.
- **Level pip (click):** **cumulative fill** (all pips ≤ chosen light up). `set(id, lvl)`: clicking the **current** level **toggles the skill off**; otherwise sets it (can move up or down — no monotonic guard here). Row gets `.set` accent when any level chosen.

---

# 11. Admin · Review queue (`/admin/forge-queue` — ForgeQueue)

*Admin-only. `canReview` = manage_stater/edit_any_project/manage_resources/review_skillcard/manage_members.
Non-reviewers see "The forge queue is for administrators with review authority."*

### Filter chips (toggle)
- All · Badge · Resource · Need · Completion, plus **Milestone** (if `manage_stater/edit_any_project/manage_resources`) and **Settlement** (if `manage_stater/edit_any_project`). Settlement filter hides the forge list; capacity section shows only on "All".

### Batch grouping (display)
- Requests sharing a `batch_id` collapse into one group (×count) — a multi-skill badge submission reviews as **one row**. `detailLines()` renders the actual content: resource → "{type} · {quota} {unit}/mo" + "Skills: …" + description; need → "{Leader|Labor|Resource need} · quota · ×headcount" + "Requires: …"; batched badges → per-item "{skill} → {Level}" chips. Fee "−{fee} STR" when >0.

### Approve (button, per group) → "Approved."
- `disabled={busy===g.key}`. `reviewGroup(g, true)` → **loops every id in the batch** → RPC `review_forge({ p_request, p_approve: true, p_note: null })`. **Downstream:** a badge raise becomes a real `badge` row; a resource flips to `approved` (offerable); a need/completion is accepted. Reload removes the row.

### Reject (button, per group) → "Rejected."
- `reviewGroup(g, false)` → per-id RPC `review_forge({ p_approve: false })`. Resource → `rejected` on the member card.

*Approve/Reject act on the whole `batch_id` group at once — effectively one decision per batch.*

### Capacity — Approve / Reject (button) — "All" filter only
- `reviewCap(c, approve)` → RPC `review_capacity({ p_commitment, p_approve })`.

### Milestone — Verify / Reject (button) — when permitted
- `reviewMilestone(m, approve)` → RPC `verify_milestone({ p_milestone, p_approve })`.

### Settlement — Approve & pay / Reject (button) — when permitted
- `reviewSettlement(s, approve)` → approve: RPC `approve_settlement({ settlement_id })` (pays out STR); reject: RPC `reject_settlement({ settlement_id, reason })`.

*All review handlers set `busy` to the row id, surface `e.message` on failure, and `load()` afterward.
"Nothing awaiting review." when empty.*

---

*Other admin consoles (People & access, Projects taxonomy, Guild & skills, Resources & economy,
Announcements, First-author writing) are lookup/governance editors — documented at control-level in
`interaction-inventory.md`; this file covers the operational interaction flows.*
