# Control-level Interaction Inventory — every button, link, field

*Auto-extracted (brace-aware) from source on `main`. Per file: each `<button>` as **label · action · disabled-when**, each link, each bound input.*


## `lib/Breadcrumbs.svelte`

**Links:** (icon) → `it.href`

## `lib/CardDrawer.svelte`
| button | does | disabled when |
|---|---|---|
| ✕ | `onClose` |  |

## `lib/EntityCard.svelte`
| button | does | disabled when |
|---|---|---|
| (icon) | `—` |  |

## `lib/GettingStarted.svelte`
| button | does | disabled when |
|---|---|---|
| Dismiss | `dismiss` |  |

**Links:** Read how it works → → `/guide` · → → `s.href`

## `lib/Hint.svelte`
| button | does | disabled when |
|---|---|---|
| ? | `(e) => { e.preventDefault(); open = !open; }` |  |

**Links:** Learn more → → `/guide#term-${term}`

## `lib/LangSwitcher.svelte`
| button | does | disabled when |
|---|---|---|
| (icon) | `() => (open = !open)` |  |
| ✓ | `() => choose(l.code)` |  |

## `lib/LaunchBanner.svelte`
| button | does | disabled when |
|---|---|---|
| × | `() => dismiss(n)` |  |
| 📣 | `() => restore(n)` |  |

**Links:** Open → → `n.href`

## `lib/Leaderboard.svelte`

**Links:** you / A member-card: managed by a chapter officer; value is custodial until the person signs up. / card → `/members/${r.id}` · (icon) → `/units/${u.id}` · you / STR → `p.href`
**Inputs:** q

## `lib/LookupEditor.svelte`
| button | does | disabled when |
|---|---|---|
| Save | `() => save(row)` |  |
| Delete | `() => remove(row.id)` |  |
| Add | `add` |  |

## `lib/MemberDetail.svelte`
| button | does | disabled when |
|---|---|---|
| Saving… / Save | `saveProfile` | `profileSaving` |
| Cancel edit | `() => (editResId = '')` |  |
| Edit | `() => (editResId = r.id)` |  |
| Remove | `() => removeResource(r.id)` |  |

**Links:** ↗ → `v` · (icon) → `/projects/${p.id}`
**Inputs:** pAffiliation, pBio

## `lib/MiningCockpit.svelte`

**Links:** → → `nextAction.href` · Ready to settle / First author / Contributor / contributed → `/projects/${p.id}` · Your team / collaborators / with free time this month / Open console → `chapters[0] ? `/officer/${chapters[0].unit_id}` : `

## `lib/SectionNav.svelte`

**Links:** (icon) → `#${s.id}`

## `lib/StartHere.svelte`
| button | does | disabled when |
|---|---|---|
| ✕ | `() => (dismissed = true)` |  |

**Links:** → → `st.href`

## `lib/admin/AdminConsole.svelte`
| button | does | disabled when |
|---|---|---|
| (icon) | `() => select(tb.key)` |  |

## `lib/admin/UnitApplications.svelte`
| button | does | disabled when |
|---|---|---|
| Approve | `() => decide(a, true)` | `busy === a.member_id + a.org_unit_id` |
| Decline | `() => decide(a, false)` | `busy === a.member_id + a.org_unit_id` |

**Links:** (icon) → `/members/${a.member_id}`

## `lib/admin/access/OfficersPanel.svelte`
| button | does | disabled when |
|---|---|---|
| Sending… / Invite | `forgeOfficer` | `sending` |
| ✓ | `() => saveEmail(p.id)` |  |
| ✕ | `() => (editEmailId = null)` |  |
| ✎ | `() => { editEmailId = p.id; emailDraft = p.email; }` |  |
| ✕ | `() => removeOfficer(o)` | `busy === o.org_unit_id + o.member_id + o.role` |
| Assign | `() => assign(u)` | `busy === u.id \|\| !dMember[u.id]` |
| Creating… / Create | `createWG` | `creating` |

**Links:** (icon) → `/members/${o.member_id}`
**Inputs:** emailDraft, fAffil, fEmail, fName, fPos, wgCode, wgName

## `lib/admin/access/PermissionsPanel.svelte`
| button | does | disabled when |
|---|---|---|
| (icon) | `() => toggle(p.id, c.key)` | `busy === cell(p.id, c.key)` |
| Done / Edit descriptions | `() => (editing = !editing)` |  |
**Inputs:** c.description

## `lib/admin/economy/CommunityResourcesPanel.svelte`
| button | does | disabled when |
|---|---|---|
| Cancel edit | `() => (editResId = '')` |  |
| Edit | `() => (editResId = r.id)` |  |

## `lib/admin/economy/SkillLevelPicker.svelte`
| button | does | disabled when |
|---|---|---|
| (icon) | `() => set(s.id, lvl)` |  |

## `lib/admin/economy/StrEconomyPanel.svelte`
| button | does | disabled when |
|---|---|---|
| Mint | `mint` |  |
| Grant | `grant` |  |
| Issue to all active members | `allowance` |  |
**Inputs:** grantAmt, grantReason, grantTo, mintAmt, mintReason, p.value, r.rate

## `lib/admin/guild/LeaderReqPanel.svelte`
| button | does | disabled when |
|---|---|---|
| ✕ | `() => remove(r.skill_id)` |  |
| Add requirement | `add` | `!reqSkill` |
**Inputs:** reqLevel, reqSkill

## `lib/admin/guild/SkillTreePanel.svelte`
| button | does | disabled when |
|---|---|---|
| Add skill | `add` | `adding` |
| ✕ | `() => remove(root.id)` |  |
| ✕ | `() => remove(c.id)` |  |

**Links:** the Guild → `/community?tab=badges`
**Inputs:** newName, newParent

## `lib/cards/BadgeTree.svelte`
| button | does | disabled when |
|---|---|---|
| (icon) | `() => setRank(s.id, rank)` | `!canEdit` |
| Submit {n} for review | `submit` | `busy` |
| Reset | `() => (draft = { ...current })` | `busy` |

## `lib/cards/CardBinder.svelte`
| button | does | disabled when |
|---|---|---|
| Add a member | `() => (showForgeMember = !showForgeMember)` |  |
| ✕ | `() => (forgeBadgeFor = null)` |  |

## `lib/cards/CommitChip.svelte`
| button | does | disabled when |
|---|---|---|
| Edit | `onEdit` |  |

## `lib/cards/ForgeCard.svelte`
| button | does | disabled when |
|---|---|---|
| Cancel | `onCancel` |  |
| Create | `—` | `busy \|\| !valid` |
**Inputs:** bLevel, bSkill, mAffil, mEmail, mHours, mName, mSkillLevels, nHead, nKind, nQuota, nResType, nSkillLevels, rName, rQuota, rScope, rType, rUnit

## `lib/cards/ForgeQueue.svelte`
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

## `lib/cards/InlineField.svelte`
| button | does | disabled when |
|---|---|---|
| ✎ | `start` |  |
**Inputs:** draft

## `lib/cards/MatchConsole.svelte`
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
| Confirm seat | `seat` | `busy === 'seat' \|\| seatOver \|\| seatUnder \|\| (!!selNeed.resource_` |
| Post need | `() => (postNeedFor = p)` |  |
| ✕ | `() => (forgeBadgeFor = null)` |  |
| ✕ | `() => (postNeedFor = null)` |  |

**Links:** needs {lvl} → `/projects/${n.project_id}`
**Inputs:** amount, cName, cProposal, cStatus, cSummary, cType, q, resId

## `lib/cards/Matcher.svelte`
| button | does | disabled when |
|---|---|---|
| ✕ | `onClose` |  |
| needs {lvl} | `() => pick(d)` | `!d.q.ok` |
| Seat | `() => confirm(d.s)` | `busy === d.s.id \|\| (d.s.slot_kind === 'work_resource' && !resId)` |
**Inputs:** amount, resId

## `lib/cards/MemberCard.svelte`
| button | does | disabled when |
|---|---|---|
| no quota / {n} slots | `onToggle` |  |
| Invest in project | `onMatch` |  |
| Forge badge | `onForgeBadge` |  |

## `lib/cards/ProjectCardBody.svelte`
| button | does | disabled when |
|---|---|---|
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

**Links:** · → `l.url`
**Inputs:** lKind, lNotes, lTitle, lUrl, mAgenda, mAt, mClaim, mEnds, mLoc, mRecur, mTitle, note

## `lib/cards/ProjectDetailBody.svelte`
| button | does | disabled when |
|---|---|---|
| Post a need / skill (with level) or a resource the project needs | `() => (showPostNeed = !showPostNeed)` |  |
| Releasing… / Release claim | `releaseClaim` | `releasing` |

**Links:** Projects → `/projects` · Manage in slot board / Open slot board → `/officer/${g.wgUnitId}`

## `lib/cards/ProjectSlotCard.svelte`
| button | does | disabled when |
|---|---|---|
| Post need | `onPostNeed` |  |
| Mint done | `onMintDone` |  |

## `lib/cards/SettlementForm.svelte`
| button | does | disabled when |
|---|---|---|
| Submit settlement for review | `submit` | `busy` |
| Cancel | `() => onCancel?.()` |  |
**Inputs:** notes, r.weight

## `lib/cards/SlotBoard.svelte`
| button | does | disabled when |
|---|---|---|
| Claim | `() => doClaim(p)` | `busy === p.id` |
| ✕ | `() => (postNeedFor = null)` |  |

## `lib/cards/SlotSeater.svelte`
| button | does | disabled when |
|---|---|---|
| needs {lvl} | `() => openPicker(s)` |  |
| (icon) | `() => pickCard(s, d.c.id)` | `!d.q.ok` |
| Seat | `() => seat(s)` | `busy === s.id \|\| over \|\| under \|\| (s.slot_kind === 'work_resourc` |
| Add directly / forge a slot for someone & seat them now | `() => (daOpen = !daOpen)` |  |
| (icon) | `() => { daMember = c.id; daResource = ''; }` |  |
| Labor | `() => (daKind = 'work_labor')` |  |
| Resource | `() => (daKind = 'work_resource')` |  |
| Create & seat | `seatDirect` | `daBusy` |

**Links:** Add it on their card → → `/members/${daMember}`
**Inputs:** amount, daAmount, daHours, daLevel, daQ, daResType, daResource, daSkill, q, resId

## `lib/cards/UnitDrawerBody.svelte`
| button | does | disabled when |
|---|---|---|
| Add a member | `() => { forgeOpen = true; forgeErr = ''; forgeMsg = ''; }` |  |
| Forging… / Forge card | `forgeMember` | `forgeBusy` |
| Cancel | `() => (forgeOpen = false)` |  |

**Links:** (icon) → `/members/${o.member_id}` · (icon) → `/members/${m.id}` · (icon) → `/projects/${p.id}`
**Inputs:** fEmail, fName

## `lib/resources/ResourceForgeForm.svelte`
| button | does | disabled when |
|---|---|---|
| Working… / Save changes / Post need / Add resource | `forge` | `busy` |
**Inputs:** fApi, fDetails, fGpu, fHeadcount, fName, fQuota, fSkillLevels, fType, fUsd, holder

## `routes/+layout.svelte`
| button | does | disabled when |
|---|---|---|
| (icon) | `() => (menuOpen = !menuOpen)` |  |
| Overview | `() => go('/')` |  |
| My profile | `() => go($member ? `/members/${$member.id}` : '/profile')` |  |
| Sign out | `signOut` |  |
| (icon) | `toggleTheme` |  |

**Links:** The&nbsp;Fin&nbsp;AI · Community → `/` · Home → `/` · Projects → `/projects` · Console → `/officer` · Community → `/community` · Guide → `/guide` · Admin → `/admin` · Net value → `/wallet` · read how the community works → → `/guide`

## `routes/+page.svelte`

**Links:** Guide → `/guide` · → → `/projects/${a.open_need.project.id}` · Badge catalog → → `/community?tab=badges` · Manage your resources & profile → `/members/${$member.id}`

## `routes/admin/+layout.svelte`

**Links:** Admin → `/admin`

## `routes/admin/+page.svelte`

**Links:** {n} open needs → `/projects?tab=needs` · economy → → `/admin/economy?tab=str` · (icon) → `r.href` · (icon) → `c.href`

## `routes/admin/announcements/+page.svelte`
| button | does | disabled when |
|---|---|---|
| Post | `add` |  |
| Pinned / Pin | `() => patch(r.id, { pinned: !r.pinned })` | `busy === r.id` |
| Retire | `() => patch(r.id, { is_active: false, pinned: false })` | `busy === r.id` |
| Restore | `() => patch(r.id, { is_active: true })` | `busy === r.id` |
| Delete | `() => remove(r.id)` | `busy === r.id` |
**Inputs:** body, ctaLabel, href, level, title

## `routes/admin/guild/+page.svelte`

**Links:** (icon) → `/members/${m.member_id}`

## `routes/admin/milestone-catalog/+page.svelte`

**Links:** Approvals → `/admin/approvals`

## `routes/admin/writing/+page.svelte`
| button | does | disabled when |
|---|---|---|
| Sending… / Remind all ({n}) | `() => remind(null)` | `sending` |
| Remind selected ({n}) | `() => remind(selectedIds)` | `sending \|\| selectedIds.length === 0` |

**Links:** (icon) → `/projects/${l.project_id}`

## `routes/community/+page.svelte`
| button | does | disabled when |
|---|---|---|
| Application pending / Apply to join | `() => applyUnit(u.id)` | `drawerBusy \|\| myUnitStatus[u.id] === 'pending'` |
| Award this badge | `openAward` |  |
| (icon) | `() => toggleAward(ac.id)` |  |
| Submitting… / Submit {n} for review / Submit for review | `() => doAward(c.id)` | `awardBusy \|\| !awardSel.size` |
| Cancel | `() => (awardOpen = false)` |  |

**Links:** Open full page → `/members/${r.id}` · Open officer console → `/officer/${u.id}` · (icon) → `/members/${h.member_id}`
**Inputs:** awardLevel, awardQ, q

## `routes/guide/+page.svelte`

**Links:** Open your officer console → → `/officer` · (icon) → `tn.href ?? `#${tn.id}` · Open your officer console → → `/officer` · Open your officer console → → `/officer` · Read the full STR paper — the dollar anchor & pricing → → `/str` · Officer console → `/officer` · Community → `/community` · Projects → `/projects` · Review queue → `/admin/forge-queue` · Wallet → `/wallet`

## `routes/login/+page.svelte`
| button | does | disabled when |
|---|---|---|
| Verifying… / Verify & sign in | `—` | `verifying` |
| Use a different email | `restart` |  |
| Sending… / Send verification code | `—` | `loading` |
**Inputs:** code, email

## `routes/members/+page.svelte`

**Links:** Community → `/community`

## `routes/officer/[unitId]/+page.svelte`

**Links:** Officer console → `/officer`

## `routes/opportunities/+page.svelte`

**Links:** Open needs → `/projects?tab=needs`

## `routes/profile/+page.svelte`

**Links:** read how the community works → → `/guide`

## `routes/projects/+page.svelte`
| button | does | disabled when |
|---|---|---|
| Cancel / Start a project | `() => (showForm = !showForm)` |  |
| Creating… / Create project | `createProject` | `creating` |
| shipped / STR minted / contributors / first author | `() => openProject(r)` |  |
| Reset | `() => { q = ''; typeFilter = ''; statusFilter = ''; venueFilter = ''; }` |  |
| (icon) | `() => (sortDir = sortDir === 1 ? -1 : 1)` |  |

**Links:** Open full page → `/projects/${r.id}`
**Inputs:** cName, cOrgUnit, cProposal, cSummary, cType, cVenueId, q, sortKey, typeFilter, venueFilter

## `routes/str/+page.svelte`

**Links:** (icon) → `#${tn.id}` · officer guide → `/guide` · economy console → `/admin/economy`

## `routes/units/+page.svelte`

**Links:** Community → `/community?tab=chapters`

## `routes/units/[id]/+page.svelte`

**Links:** Open officer console → `target`