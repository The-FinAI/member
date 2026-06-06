# Old → New semantics audit (gap check before further cull)

*Triggered by the leader omission. Goal: confirm the new flow (TaskBoard ·
MatchBoard/assign · NeedPost · ProjectTeam · SkillCapacity · Home router ·
Wallet) covers every old semantic, and that nothing was dropped or any data
orphaned. Nothing here drops data.*

## Slot kinds (the leader-class bugs)
| Old `project_slot.slot_kind` | New coverage | Status |
|---|---|---|
| `leader` (first author) | was dropped → **fixed**: now a Need in MatchBoard/ProjectTeam; `match_candidates` handles it (skill or capacity-only); `assign`→`work_seat` mints first-author hours | ✅ fixed (0560) |
| `work_labor` (skill + hours) | NeedPost · MatchBoard (person_skill + capacity) · assign | ✅ |
| `work_resource` (a resource type) | NeedPost toggle · MatchBoard (holders by remaining quota) · assign | ✅ |

`work_seat` flips a slot to `filled` at headcount (rebuild_rpc L98) — filled needs drop from the board. ✅

## Project lifecycle & economy (kept, not rebuilt)
| Old function | New | Status |
|---|---|---|
| status pipeline (Proposed→…→Finished, Hold/Resume) `project_set_status` | ProjectCardBody pipeline — kept | ✅ |
| `forge_project_done` (Mint done → Finished) | ProjectCardBody — kept | ✅ |
| settlement `submit_settlement` / SettlementForm | kept + P4 fairness summary | ✅ |
| milestones `forge_milestone` | ProjectCardBody — kept | ✅ |
| `release_claim` | ProjectDetailBody — kept | ✅ |
| links / meetings / notes / history | ProjectCardBody — kept | ✅ |
| STR ledger / nominal / settled | reused; quiet Wallet on /my (P4) | ✅ |

## People / skills / capacity
| Old | New | Status |
|---|---|---|
| "My time" Labor resource = hours | `member.monthly_hours` (backfilled, P2) | ✅ |
| `badge` (certified skills, 4-tier) | `person_skill` (3-tier) — matching reads this | ⚠️ **gap → fixed**: backfill person_skill from badge (0570). Old `badge` table KEPT. |
| capacity over-allocation → `needs_review` (soft) | new `assign` HARD-blocks over capacity | ✅ (stricter by design; old needs_review rows still resolvable in Review inbox) |
| officer acts as proxy (`p_as`) | assign uses p_as=member; notify assignee (P5) | ✅ |

## Review / governance
| Old | New | Status |
|---|---|---|
| resource supply review (`forge_resource`→forge_request) | member card ResourceForgeForm — kept; Review inbox | ✅ |
| need posting via review (`forge_need`) | new `need_post` **applies immediately** (trusted officer) — no review | ✅ by design (PRD §7 trust+undo) |
| badge review (`forge_badges`) | BadgeTree still on member card → forge_request | ⏳ to retire once person_skill is the only skill source (kept for now) |
| settlement / milestone / capacity review | Review inbox (forge-queue) — kept | ✅ |

## Remaining known gaps / follow-ups (none drop data)
1. **Two skill systems coexist** (old `badge`/BadgeTree + new `person_skill`/SkillCapacity). Backfill (0570) makes new matching see old skills; the BadgeTree UI is **slated to retire** in the people-card restructure, but only after person_skill is confirmed authoritative. No data deleted either way.
2. **Resource match doesn't filter `approval_status`** — an unapproved member resource can currently appear as a candidate. Low risk; tighten `match_candidates` resource branch to `approval_status = 'approved'` when we confirm the column's live values.
3. **`need_post` applies without review** — intentional (trusted officer, PRD §7), but worth a note: a future "light handshake" for cross-unit posting (PRD §7 tier 2) is not built.

## Verdict
The only **data-continuity** gap was badges → person_skill (now backfilled, non-destructive). The leader gap is fixed. Everything else is either covered, intentionally kept, or a scheduled UI retirement that deletes no data. Safe to continue the people-card restructure — but BadgeTree retirement must wait until person_skill is verified authoritative on a live push.
