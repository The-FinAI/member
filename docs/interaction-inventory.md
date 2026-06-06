# Current-state Interaction Inventory (as-is)

*Every interaction that exists today, surface by surface, regardless of role. This is the
**as-is** map (the truth on `main`), captured before redesign. Each row: **action — effect
(RPC) — who can do it**. Roles: `P`=President/admin · `C`=Chapter officer (manages **people
+ matching**) · `W`=WG officer (manages **projects**) · `L`=project leader/first-author ·
`R`=any signed-in member · `me`=on your own record.*

> Role split (confirmed): **WG officer → projects. Chapter officer → people & matching.**

---

## 0. Roles & permission groups (today)
- **President** holds `manage_stater` etc. → full authority.
- **Officer** = a row in `org_unit_officer` for a unit, role `chair/secretary` (chapter) or
  `leader` (working group). Capabilities come from their `position` via `position_capability`.
- Capabilities (raw keys, shown in admin): `manage_members, invite_members, edit_any_project,
  review_skillcard, mint_skillcard, manage_guild, manage_taxonomy, manage_resources,
  manage_stater, manage_tokens`.

---

## 1. Login (`/login`)
- **Enter email → Send code** — checks `is_email_invited`; if invited, `signInWithOtp`
  (shouldCreateUser true). Unclaimed cards are rejected. `[anyone invited]`
- **Enter code → Verify** — `verifyOtp` → session; layout binds member by email. `[anyone]`

## 2. Global shell (`+layout.svelte`)
- **Sidebar nav**: Home · Work(Projects, Console) · More(Community, Guide, Admin). Role-gated
  (Console if officer/admin; Admin if admin/approver). `[all]`
- **Wallet chip** (footer) — net STR → `/wallet`. **Avatar menu** → profile/members/[id],
  theme, lang, sign out. `[R]`
- Reads `stater_balance`, project nominal for the chip.

## 3. Home (`/`)
- **Identity header** (name, role pills, Guide↗). `[R]`
- **MiningCockpit** — focal ring (claimable vs accruing STR); one-line status; **single next
  action** (Settle / Assign collaborators / Find a project); **Your projects** (link each);
  **Your team** (officer → console). Reads `stater_balance`, `work_commitment`,
  `stater_settlement`, `member`, `resource`. `[R; team lane = C/W]`
- (legacy still imported: `StartHere`, `GettingStarted` P2-only.)

## 4. Projects list (`/projects`)
- **Browse grid** (EntityCard per project; status colour; click → `/projects/[id]`). `[all]`
- **Sort / filter** (deadline, status, etc.). `[all]`
- **Create a project** form — `create_project_phase1` (free; no auto-leader). Fields: name,
  type, status, venue, working group, proposal, summary. Gated `leader_reqs_missing` shown.
  `[R, but WG-officer to attribute to a unit]`

## 5. Project detail (`/projects/[id]` & drawer — `ProjectDetailBody`)
- **STR pipeline** — Accruing → Finish → Settle → Paid, current stage + projected payout +
  stage nudge. Reads `stater_settlement`, `project_milestone`. `[all read]`
- **Team & slots** (`ProjectSlotCard`) — read map of leader/work slots & who's seated. `[all]`
- **Post a need** (toggle → `ResourceForgeForm` mode=need) — `forge_need` (skill+level or
  resource type, headcount). `[W / L]`
- **Seat a member** (`SlotSeater`) — pick an open slot → pick a card → `work_seat`; **Add
  directly** (admin-only) forges a slot + seats via `seat_direct`. Capacity-gated. `[C/W/P seat; Add-directly = P]`
- **Release claim** — `release_claim` (detach from WG). `[W/P]`
- **Manage in slot board** → `/officer/[wgUnit]`. `[all]`
- **ProjectCardBody** (inline editors, gated by `can_edit_project`): rename/summary/venue/
  status/working-group via `project_set_*` / `project_rename` / `project_set_status`;
  **links** add/remove (`project_link_add/remove`); **meetings** add/remove
  (`project_meeting_add/remove`); **note** (`project_note`); **milestone claim**
  (`forge_milestone` from `milestone_catalog`); **mark done** (`forge_project_done`);
  history feed (`project_event`). `[L/W/P]`
- **Settlement** (`SettlementForm`, when finished) — split pool into payout weights →
  `submit_settlement`. `[L/W]`

## 6. Officer Console (`/officer` → `/officer/[unitId]` — `MatchConsole`)
`/officer` redirects a single-unit officer straight in.
### Chapter mode (people + matching)
- **Guide line** narrates state (Filling X / Placing Y / clear). `[C]`
- **Open needs ⟷ Roster** two columns; pick a need → candidates highlight/dim with reasons
  (qualify: skills + capacity); pick a person → fillable needs highlight. `[C]`
- **Seat inline** — on a qualified candidate, **Seat →** expands amount/resource/**Confirm
  seat** in-row → `work_seat`. Capacity/under/over gated. `[C/P]`
- **+ Add a member** — `ForgeCard` member mode → `forge_member_card` (badges batch) +
  `forge_resource` for "My time" hours. `[C]`
- **Badge ✦** per person → `BadgeTree` → `forge_badges` (staged ranks, one batch). `[C/P]`
### Working-group mode (projects)
- **Open needs** of the WG's projects (read → project page). `[W]`
- **Unclaimed projects → Claim** — `forge_claim`. `[W]`
- **+ Create project** — `create_project_phase1`. `[W]`
- **Post a need** against an owned project — `forge_need`. `[W]`
- **Mint completion** — `forge_project_done`. `[W]`

## 7. Community (`/community`)
- **Tabs**: People (member cards grid) · Chapters · Working Groups · Standing (per family) ·
  Badges (catalog). `[all]`
- Click a person → `/members/[id]`; a unit → `/units/[id]` (drawer). `[all]`
- **Apply to a unit** — `apply_to_unit`. `[R]`  *(parallel to officer placement)*
- **Forge badge** (officer, from a person) — `forge_badge`. `[C/P]`

## 8. Member card (`/members/[id]` & drawer — `MemberDetail`)
- **Identity header** (name, card/unclaimed badge, links, positions). `[all]`
- **Self profile edit** (affiliation, bio) — direct `member` update. `[me]`
- **Resources tab** (`ResourceForgeForm`): declare/edit a resource → `forge_resource` /
  `update_resource` (review-gated; described types = text); **Edit/Remove** rows; **stewarded
  community resources** listed. Visible to all; editable by `me`/manager/`manage_resources`.
- **Badges**: `BadgeTree` (claim/raise own → `forge_badges`; officers award others). `[me/C/P]`
- **Projects**: read list (role, contribution). **Resources KPI** on overview. `[all]`

## 9. Unit detail (`/units/[id]` — `UnitDrawerBody`)
- Read unit (officers, projects, members). **Forge member card** (chapter) —
  `forge_member_card`. Edit name/desc if `can_edit_unit`. `[C/W/P]`

## 10. Wallet (`/wallet`)
- **Hero balance** (net = liquid + nominal), liquid/nominal split, bonded ratio. `[me]`
- **How you earn STR** — 4-step loop (join → contribute → finish → settle), live figures. `[me]`
- **Activity** ledger (read `stater_ledger`); full ledger here. `[me]`

## 11. Admin (`/admin` hub + consoles)
Hub: KPIs, **Review band** (Forge/Review queue, Unit applications — counts), **Consoles**
(gated by capability). `[P/approvers]`
### 11.1 Review queue (`/admin/forge-queue` — `ForgeQueue`) — admin-only
- **Approve/Reject** each item (batches grouped); shows specific content. Dispatches:
  `review_forge` (badge/resource/need/member_card/completion), `review_capacity`
  (over-capacity commitments), `approve_settlement`/`reject_settlement`, `verify_milestone`.
  Gated by the matching capability. `[P / capability holder]`
### 11.2 Unit applications (`/admin/review` — `UnitApplications`)
- **Approve/decline** a member's unit application — `decide_unit_member`. `[C/W/P]`
### 11.3 People & access (`/admin/access` — `OfficersPanel` + `PermissionsPanel`)
- **Invite an officer** — edge fn `invite-member` (pre-creates member + email). `[P]`
- **Assign / remove officer** to a unit — `assign_org_officer` / `remove_org_officer`. `[P]`
- **Fix invitee email** — `set_member_email`. `[P]`
- **Permissions** — per-position capability chips (read `position_capability`). `[P]`
### 11.4 Projects console (`/admin/projects` — `LookupEditor`)
- CRUD **Types / Statuses / Roles / Venues** (lookup tables). `[P/manage_taxonomy]`
### 11.5 Guild & skills (`/admin/guild`)
- **Skill tree** add/branch (`SkillTreePanel` → `skill`). **Leader requirement**
  (`LeaderReqPanel` → `leader_skill_requirement`). **Skill rates** (`SkillRatesPanel` →
  `stater_skill_rate`, STR/hr). `[P/manage_guild]`
### 11.6 Resources & economy (`/admin/economy`)
- **STR economy** (`StrEconomyPanel`): balances by account type, **Mint** (`stater_mint`),
  **Grant** (`stater_grant`), **Monthly allowance** (`issue_monthly_allowance`), policy view.
  **Community resources** (`CommunityResourcesPanel` → `ResourceForgeForm`, scope=community).
  **Resource types** & **Milestone catalog** editors. `[P/manage_stater/manage_resources]`
### 11.7 Announcements (`/admin/announcements`)
- Post / pin / retire notices (`announcement`); shown via `LaunchBanner`. `[P/manage_members]`
### 11.8 First-author writing (`/admin/writing`)
- **Writing laggards** report — `writing_laggards` (leaders behind on writing hours). `[P]`

## 12. Shared components (interaction primitives)
- **EntityCard** — whole-card click → its drawer/route. (used everywhere)
- **CardDrawer** — backdrop/✕ close; slide-in detail+editor.
- **SectionNav** — in-page tabs that show/hide sections (member/project detail).
- **SkillLevelPicker / BadgeTree** — leaf skills × 4 level pips; click to set/stage.
- **ResourceForgeForm** — type-adaptive (GPU/API/USD/flat/labour→SkillLevelPicker/described→
  text); modes supply(`forge_resource`)/need(`forge_need`)/edit(`update_resource`).
- **ForgeCard** — member/badge/resource/need form shell (member & need modes live).
- **Hint** — tooltip term explainer. **Breadcrumbs** — back trail. **LangSwitcher**, **CountUp**.

## 13. Legacy / dead surfaces still in the repo (no real entry or superseded)
- Routes: `/opportunities`, `/officer/chapter/[unitId]`, `/officer/wg/[unitId]` (redirect),
  `/profile` (redirect), `/units` (no `[id]`-less use), plus ~15 legacy `/admin/*` per-table
  routes (approvals, capabilities, invites, milestone-catalog, org-units, positions,
  resource-types, resources, roles, skills, statuses, types, venues) overlapping the consoles.
- Components: `SlotBoard`, `Matcher`, `MemberCard`, `CardBinder`, `GettingStarted`,
  `CommitChip`, `InlineField` (verify usage), `ProjectSlotCard` (read-only).
- Backend: the 6 dead subsystems (PRD §13.1).

---

*Use this as the checklist for the redesign: each row is an interaction that must be either
**kept (and re-skinned to the north-star vocabulary), merged, or deleted** — and re-pointed
at the right role (WG=projects, Chapter=people+matching).*
