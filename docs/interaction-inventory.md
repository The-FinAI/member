# Interaction Inventory — pages + controls (as-is)

*One doc: every user-facing **page**, then every **control** on it (button → action · disabled-when), its links and inputs. Roles: P=President/admin · C=Chapter officer (people+matching) · W=WG officer (projects) · L=project leader · R=member · me=self.*


## Login
`/login` · roles: anyone invited

| button | does | disabled when |
|---|---|---|
| Verifying… / Verify & sign in | `—` | `verifying` |
| Use a different email | `restart` |  |
| Sending… / Send verification code | `—` | `loading` |
**Inputs:** code, email

## Global shell (sidebar, wallet chip, avatar menu)
`every page` · roles: all

| button | does | disabled when |
|---|---|---|
| (icon) | `() => (menuOpen = !menuOpen)` |  |
| Overview | `() => go('/')` |  |
| My profile | `() => go($member ? `/members/${$member.id}` : '/profile')` |  |
| Sign out | `signOut` |  |
| (icon) | `toggleTheme` |  |

**Links:** Admin → `/admin` · Community → `/community` · Console → `/officer` · Guide → `/guide` · Home → `/` · Net value → `/wallet` · Projects → `/projects` · The&nbsp;Fin&nbsp;AI · Community → `/` · read how the community works → → `/guide`

## Home
`/` · roles: R (team lane = C/W)

| button | does | disabled when |
|---|---|---|
| ✕ | `() => (dismissed = true)` |  |

**Links:** Badge catalog → → `/community?tab=badges` · Guide → `/guide` · Manage your resources & profile → `/members/${$member.id}` · Ready to settle / First author / Contributor / contributed → `/projects/${p.id}` · Your team / collaborators / with free time this month / Open console → `chapters[0] ? `/officer/${chapters[0].unit_id}` ` · → → `/projects/${a.open_need.project.id}` · → → `nextAction.href` · → → `st.href`

## Projects — list & create
`/projects` · roles: all; create=R/W

| button | does | disabled when |
|---|---|---|
| Cancel / Start a project | `() => (showForm = !showForm)` |  |
| Creating… / Create project | `createProject` | `creating` |
| shipped / STR minted / contributors / first author | `() => openProject(r)` |  |
| Reset | `() => { q = ''; typeFilter = ''; statusFilter = ''; venueFilter = ''; }` |  |
| (icon) | `() => (sortDir = sortDir === 1 ? -1 : 1)` |  |

**Links:** Open full page → `/projects/${r.id}`
**Inputs:** cName, cOrgUnit, cProposal, cSummary, cType, cVenueId, q, sortKey, typeFilter, venueFilter

## Project detail
`/projects/[id] (+drawer)` · roles: all read; edit=L/W; admin=P

| button | does | disabled when |
|---|---|---|
| Post a need / skill (with level) or a resource the project needs | `() => (showPostNeed = !showPostNeed)` |  |
| Releasing… / Release claim | `releaseClaim` | `releasing` |
| Resume | `resume` | `busy === 'status'` |
| Hold | `hold` | `busy === 'status'` |
| (icon) | `() => clickable && setStatus(s.id)` | `!clickable \|\| busy === 'status'` |
| Mint done | `mintDone` | `busy === 'done'` |
| Open settlement | `() => (showSettle = true)` |  |
| Cancel / Add link | `() => (showAddLink = !showAddLink)` |  |
| Add link | `addLink` | `busy === 'link'` |
| ✕ | `() => removeLink(l.id)` | `busy === l.id` |
| Cancel / Schedule meeting | `() => (showAddMeeting = !showAddMeeting)` |  |
| Schedule meeting | `addMeeting` | `busy === 'meeting'` |
| ✕ | `() => removeMeeting(m.id)` | `busy === m.id` |
| Claim | `claimMilestone` | `busy === 'milestone' \|\| !mClaim` |
| Post | `postNote` | `busy === 'note' \|\| !note.trim()` |
| Post need | `onPostNeed` |  |
| Mint done | `onMintDone` |  |
| needs {lvl} | `() => openPicker(s)` |  |
| (icon) | `() => pickCard(s, d.c.id)` | `!d.q.ok` |
| Seat | `() => seat(s)` | `busy === s.id \|\| over \|\| under \|\| (s.slot_kind === 'wo` |
| Add directly / forge a slot for someone & seat them now | `() => (daOpen = !daOpen)` |  |
| (icon) | `() => { daMember = c.id; daResource = ''; }` |  |
| Labor | `() => (daKind = 'work_labor')` |  |
| Resource | `() => (daKind = 'work_resource')` |  |
| Create & seat | `seatDirect` | `daBusy` |
| Submit settlement for review | `submit` | `busy` |
| Cancel | `() => onCancel?.()` |  |

**Links:** Add it on their card → → `/members/${daMember}` · Manage in slot board / Open slot board → `/officer/${g.wgUnitId}` · Projects → `/projects` · · → `l.url`
**Inputs:** amount, daAmount, daHours, daLevel, daQ, daResType, daResource, daSkill, lKind, lNotes, lTitle, lUrl, mAgenda, mAt, mClaim, mEnds, mLoc, mRecur, mTitle, note, notes, q, r.weight, resId

## Officer Console (Chapter=people+matching · WG=projects)
`/officer/[unitId]` · roles: C/W/P

| button | does | disabled when |
|---|---|---|
| Add a member | `() => (showForgeMember = !showForgeMember)` |  |
| Create project | `() => (showCreate = !showCreate)` |  |
| Create project | `doCreate` | `busy === 'create'` |
| Claim | `() => claim(p)` | `busy === p.id` |
| clear | `() => (selNeed = null)` |  |
| clear | `() => (selPerson = null)` |  |
| needs {lvl} | `() => pickNeed(n)` |  |
| card / hours full / {used}/{quota} {unit} used / {n} badges | `() => pickPerson(p)` |  |
| Seat | `() => pickPerson(p)` |  |
| ✦ | `() => (forgeBadgeFor = p)` |  |
| Confirm seat | `seat` | `busy === 'seat' \|\| seatOver \|\| seatUnder \|\| (!!selNeed` |
| Post need | `() => (postNeedFor = p)` |  |
| ✕ | `() => (forgeBadgeFor = null)` |  |
| ✕ | `() => (postNeedFor = null)` |  |
| (icon) | `() => setRank(s.id, rank)` | `!canEdit` |
| Submit {n} for review | `submit` | `busy` |
| Reset | `() => (draft = { ...current })` | `busy` |
| Cancel | `onCancel` |  |
| Create | `—` | `busy \|\| !valid` |

**Links:** Officer console → `/officer` · needs {lvl} → `/projects/${n.project_id}`
**Inputs:** amount, bLevel, bSkill, cName, cProposal, cStatus, cSummary, cType, mAffil, mEmail, mHours, mName, mSkillLevels, nHead, nKind, nQuota, nResType, nSkillLevels, q, rName, rQuota, rScope, rType, rUnit, resId

## Community (directory)
`/community` · roles: all

| button | does | disabled when |
|---|---|---|
| Application pending / Apply to join | `() => applyUnit(u.id)` | `drawerBusy \|\| myUnitStatus[u.id] === 'pending'` |
| Award this badge | `openAward` |  |
| (icon) | `() => toggleAward(ac.id)` |  |
| Submitting… / Submit {n} for review / Submit for review | `() => doAward(c.id)` | `awardBusy \|\| !awardSel.size` |
| Cancel | `() => (awardOpen = false)` |  |

**Links:** (icon) → `/members/${h.member_id}` · Open full page → `/members/${r.id}` · Open officer console → `/officer/${u.id}`
**Inputs:** awardLevel, awardQ, q

## Member card
`/members/[id] (+drawer)` · roles: all; edit=me/manager/P

| button | does | disabled when |
|---|---|---|
| Saving… / Save | `saveProfile` | `profileSaving` |
| Cancel edit | `() => (editResId = '')` |  |
| Edit | `() => (editResId = r.id)` |  |
| Remove | `() => removeResource(r.id)` |  |
| (icon) | `() => setRank(s.id, rank)` | `!canEdit` |
| Submit {n} for review | `submit` | `busy` |
| Reset | `() => (draft = { ...current })` | `busy` |

**Links:** (icon) → `/projects/${p.id}` · ↗ → `v`
**Inputs:** pAffiliation, pBio

## Unit detail
`/units/[id]` · roles: all; edit=officer

| button | does | disabled when |
|---|---|---|
| Add a member | `() => { forgeOpen = true; forgeErr = ''; forgeMsg = ''; }` |  |
| Forging… / Forge card | `forgeMember` | `forgeBusy` |
| Cancel | `() => (forgeOpen = false)` |  |

**Links:** (icon) → `/members/${m.id}` · (icon) → `/members/${o.member_id}` · (icon) → `/projects/${p.id}` · Open officer console → `target`
**Inputs:** fEmail, fName

## Wallet
`/wallet` · roles: me

## Admin hub
`/admin` · roles: P/approvers

**Links:** (icon) → `c.href` · (icon) → `r.href` · economy → → `/admin/economy?tab=str` · {n} open needs → `/projects?tab=needs`

## Admin · Review queue
`/admin/forge-queue` · roles: P / capability holder

| button | does | disabled when |
|---|---|---|
| All | `() => (filter = f as any)` |  |
| Approve | `() => reviewGroup(g, true)` | `busy === g.key` |
| Reject | `() => reviewGroup(g, false)` | `busy === g.key` |
| Approve | `() => reviewCap(c, true)` | `busy === c.id` |
| Reject | `() => reviewCap(c, false)` | `busy === c.id` |
| Verify | `() => reviewMilestone(m, true)` | `busy === m.id` |
| Reject | `() => reviewMilestone(m, false)` | `busy === m.id` |
| Approve & pay | `() => reviewSettlement(s, true)` | `busy === s.id` |
| Reject | `() => reviewSettlement(s, false)` | `busy === s.id` |

## Admin · Unit applications
`/admin/review` · roles: C/W/P

| button | does | disabled when |
|---|---|---|
| Approve | `() => decide(a, true)` | `busy === a.member_id + a.org_unit_id` |
| Decline | `() => decide(a, false)` | `busy === a.member_id + a.org_unit_id` |

**Links:** (icon) → `/members/${a.member_id}`

## Admin · People & access
`/admin/access` · roles: P

| button | does | disabled when |
|---|---|---|
| Sending… / Invite | `forgeOfficer` | `sending` |
| ✓ | `() => saveEmail(p.id)` |  |
| ✕ | `() => (editEmailId = null)` |  |
| ✎ | `() => { editEmailId = p.id; emailDraft = p.email; }` |  |
| ✕ | `() => removeOfficer(o)` | `busy === o.org_unit_id + o.member_id + o.role` |
| Assign | `() => assign(u)` | `busy === u.id \|\| !dMember[u.id]` |
| Creating… / Create | `createWG` | `creating` |
| (icon) | `() => toggle(p.id, c.key)` | `busy === cell(p.id, c.key)` |
| Done / Edit descriptions | `() => (editing = !editing)` |  |

**Links:** (icon) → `/members/${o.member_id}`
**Inputs:** c.description, emailDraft, fAffil, fEmail, fName, fPos, wgCode, wgName

## Admin · Projects (taxonomy)
`/admin/projects` · roles: P

| button | does | disabled when |
|---|---|---|
| Save | `() => save(row)` |  |
| Delete | `() => remove(row.id)` |  |
| Add | `add` |  |

## Admin · Guild & skills
`/admin/guild` · roles: P

| button | does | disabled when |
|---|---|---|
| Add skill | `add` | `adding` |
| ✕ | `() => remove(root.id)` |  |
| ✕ | `() => remove(c.id)` |  |
| ✕ | `() => remove(r.skill_id)` |  |
| Add requirement | `add` | `!reqSkill` |

**Links:** the Guild → `/community?tab=badges`
**Inputs:** newName, newParent, reqLevel, reqSkill

## Admin · Resources & economy
`/admin/economy` · roles: P

| button | does | disabled when |
|---|---|---|
| Mint | `mint` |  |
| Grant | `grant` |  |
| Issue to all active members | `allowance` |  |
| Cancel edit | `() => (editResId = '')` |  |
| Edit | `() => (editResId = r.id)` |  |
**Inputs:** grantAmt, grantReason, grantTo, mintAmt, mintReason, p.value, r.rate

## Admin · Announcements
`/admin/announcements` · roles: P

| button | does | disabled when |
|---|---|---|
| Post | `add` |  |
| Pinned / Pin | `() => patch(r.id, { pinned: !r.pinned })` | `busy === r.id` |
| Retire | `() => patch(r.id, { is_active: false, pinned: false })` | `busy === r.id` |
| Restore | `() => patch(r.id, { is_active: true })` | `busy === r.id` |
| Delete | `() => remove(r.id)` | `busy === r.id` |
**Inputs:** body, ctaLabel, href, level, title

## Admin · First-author writing
`/admin/writing` · roles: P

| button | does | disabled when |
|---|---|---|
| Sending… / Remind all ({n}) | `() => remind(null)` | `sending` |
| Remind selected ({n}) | `() => remind(selectedIds)` | `sending \|\| selectedIds.length === 0` |

**Links:** (icon) → `/projects/${l.project_id}`

## Shared form: ResourceForgeForm (resource declare/edit + post need)
`member card · console · community · project` · roles: varies

| button | does | disabled when |
|---|---|---|
| Working… / Save changes / Post need / Add resource | `forge` | `busy` |
**Inputs:** fApi, fDetails, fGpu, fHeadcount, fName, fQuota, fSkillLevels, fType, fUsd, holder

## Shared: SkillLevelPicker (skill+level tree)
`add-member · need · badges · resource` · roles: varies

| button | does | disabled when |
|---|---|---|
| (icon) | `() => set(s.id, lvl)` |  |