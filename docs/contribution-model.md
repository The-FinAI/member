# Contribution model & role user stories

> Draft spec for review. No code or DB changes made yet.
> Confirmed decisions: time == resource (one "contribution" concept);
> monthly time is a **standing commitment** (pledge once, auto-accrues).
> One decision still open — see §6.

## 1. The two things we kept conflating

| Concept | What it is | Unit | Fate at settlement |
|---|---|---|---|
| **Bond** | Skin in the game. A lock-up that says "I'm serious." | STR | Returned to the pot, then redistributed (or slashed if you flaked) |
| **Contribution** | The value you actually create | hrs/month, GPU-hrs, $, dataset… | Determines your **share** of the pot |

Today both live under "staking," which is why it's muddled. Splitting them
makes settlement trivial to reason about:

> **The bonds fund the pot. The contributions decide the split.**
> Bond a lot but contribute nothing → you mostly funded other people.
> Contribute a lot → you claim more than you put in.

## 2. Contribution = one concept, several flavors

A contribution is *something of value a member commits to a project*, with a
capacity, a unit, and a STR valuation. **Labor is just the labor-typed
resource.**

| Flavor | Capacity unit | Valuation | Recurring? |
|---|---|---|---|
| **Labor** (a member's time) | **hrs / month** | `hours × skill_rate` | yes (monthly) |
| Compute | GPU-hrs / month | steward-set token-equiv | optional |
| Funding | $ | steward-set token-equiv | optional |
| Data / equipment | lump | steward-set token-equiv | no |

Because labor is recurring, **monthly** is the natural cadence for the whole
resource model — a contribution can be a one-off lump *or* an `X / month`
standing pledge.

### Standing commitment (confirmed)
A member pledges e.g. **40 hrs/month** once, at join. It auto-accrues for the
project's active life — no monthly timesheet to file. At any moment:

```
accrued_value = capacity_per_month × active_months × rate
active_months = months( joined_at … now-or-finish )
```

This is low-friction and deterministic. (A stricter "monthly timesheet +
leader verify" mode can be layered on later for projects that want it, reusing
the existing `verify_commitment` pattern — out of scope for v1.)

## 3. Roles

| Role | Backing | Core want |
|---|---|---|
| **Contributor** | any member | Find a project, pledge time/resources, earn a fair share |
| **Leader** | `project_member.can_manage` | Assemble a team, ship to a venue, split the reward |
| **Resource steward** | `manage_resources` | Vet pledged resources/labor so offers are real |
| **Stater manager** | `manage_stater` | Approve settlements, keep the economy honest |
| **Org admin** | president | Invite members, set taxonomy + economic policy |

## 4. Lifecycle as role-framed stories (not one screen)

### Proposal
- **Leader**: create project, post a **bond**, set target venue/deadline,
  post **needs**. A need is "I want a *contribution*": e.g. *Labor — 40 hrs/mo
  of NLP (≥ Advanced)*, or *Compute — 200 GPU-hrs/mo*.
- **Contributor**: browse Opportunities, apply to a need with a pitch.

### Data collecting / Work in progress
- **Contributor**: get accepted → **enter** by (a) posting the join bond and
  (b) registering my contribution (the monthly pledge). My accrued value ticks
  up each month automatically.
- **Leader**: see live roster with each person's *pledged capacity* and
  *accrued value to date*; close/adjust needs; verify one-off resources.
- **Steward**: approve member resources/labor pledges before they count
  (the approval gate already drafted).

### Under review
- **Leader**: freeze contributions; draft settlement. Payout weights are
  **pre-filled from accrued contribution value** (not typed from scratch),
  plus authorship.
- **Steward / Stater**: sanity-check the proposed split.

### Finished
- **Stater manager**: approve settlement → escrow (the pooled bonds) +
  minted finish bonus distributed by accrued contribution value + authorship.
- **Contributor**: bond returns folded into payout; sees a payout event
  (the wallet celebration we built).

## 5. Data-model deltas (proposed, not applied)

Mostly reuses what exists (`stater_project_stake_commitment` already carries
`commitment_type`, `skill_id`, `resource_id`, `hours_committed`,
`token_amount`, `token_equivalent`).

1. **Add a `Labor` resource type** (seed) and treat a member's time as a
   resource they hold: `resource(type=Labor, capacity='40 hrs/mo',
   holder_member_id=…)`.
2. **`commitment` gets a cadence**: `period` enum `once | monthly`, plus
   `started_at` so accrual = `amount/period × months_active`.
3. **Rename `skill_time` → `labor`** conceptually (keep both valued at
   `hours × skill_rate`).
4. **Needs become contribution-typed**: `open_need` gains a
   `contribution_kind` (labor | resource) so a need can ask for hours *or* a
   resource, not only a role seat.
5. **Settlement reads accrued value** to seed `final_payout_weight`.
6. Approval gate (already drafted in `resource_approval.sql`) now also covers
   labor pledges, since labor is a resource.

## 6. Bond model — DECIDED: keep a small bond

The STR join/leader bond **stays as a pure commitment device** (anti-flake),
kept low via policy. Payout is **100% contribution-driven**. The bond is your
buy-in to the pot; your accrued contribution value is your claim on it.

- `join_stake` / `leader_stake` policies unchanged (already low: 20/50).
- A no-show contributor can be slashed (existing `slash_leader_stake` pattern,
  extendable to members) — forfeited bond stays in escrow for the finishers.

## 7. Build plan (on green light)

1. **DB migration `contributions.sql`**
   - Seed a `Labor` resource type.
   - `open_need.contribution_kind` (`seat | labor | resource`) +
     `hours_per_month`, so a need can ask for monthly hours or a resource.
   - `stater_project_stake_commitment`: add `period` (`once | monthly`) and
     `started_at`; helper `accrued_value(commitment)` =
     `amount/period × active_months × rate`.
   - `confirm_join` extended: post the (small) bond **and** register the
     member's monthly labor pledge as a contribution.
   - `submit_settlement` pre-computes payout weights from accrued value.
   - Folds in `resource_approval.sql` (labor pledges are resources → approved
     by a steward before they count).
2. **Project page → role-framed sections**
   - Leader view vs contributor view vs steward view, phase-aware.
   - Roster shows pledged capacity + accrued value to date.
   - "My contribution" panel for the signed-in contributor.
3. **Opportunities** — needs show whether they want **hours/month** or a
   **resource**, and the bond required.
4. **Profile** — labor pledge surfaced alongside resources (already medals for
   skills; resources already gated by approval).
5. **Settlement** — weights pre-filled from accrued value, leader can tweak.

### In-flight work to reconcile
- **Skill medals** (profile) — built, **uncommitted**. Pure UI, safe to keep.
- **Resource approval** (`resource_approval.sql` + admin queue) — built,
  **not applied, uncommitted**. Now a *dependency* of this plan (labor pledges
  need the same gate), so it lands as part of step 1.
