# Contribution model & role user stories

> Spec for build. Confirmed decisions baked in:
> - **Contribution = staking.** Pledged labor/resources are *valued and minted
>   into staked STR*. Contributors also post a small **20 STR join bond** (real,
>   slashable) that funds the pool and seeds their nominal claim.
> - **Rolling monthly commitment.** Each month a member sets the hours/resources
>   they'll put in *next* month; that drives that month's minting.
> - **Declare = mint.** Declaration mints immediately into the project pool
>   (trust-based, no per-month verification gate).
> - **Leader is special.** A leader must post a real **50 STR cash bond
>   (slashable)** + commit **first authorship** + pledge their own monthly hours.
> - **Settlement is joint.** Leader drafts the split; the community (Stater
>   manager) co-approves and can adjust; both sign for it to take effect.
> - **Elastic supply.** Don't pre-mint a big fixed total. A small genesis float
>   bootstraps; real supply is minted at settlement, backed by delivered work.

## 0. Tokenomics — elastic supply, treasury, prediction-market reserve

STR supply is **demand-driven, not a fixed pre-mint**. Because contribution
mints at settlement (§1b, §4), the system's total STR ≈ the sum of all settled
work — supply tracks value, it can't inflate out of nowhere.

### Three buckets
1. **Genesis float (small).** Just enough liquid STR to bootstrap: post leader
   bonds (50 each) and pay exam fees before the first settlement pays out.
   Bonds are escrowed and return at settlement, so the float *circulates*; size
   it to *concurrent bootstrap need* (~`expected parallel projects × 50` + early
   exam fees), not to any imagined total. Start small, top up later.
2. **Work-minted supply (the body).** Real STR is minted **only at settlement**
   (the finish bonus, §4), backed 1:1 (policy `finish_bonus_ratio`, default 1.0)
   by accrued nominal value. Every minted STR represents delivered work, so
   *supply = realized value*.
3. **Treasury reserve (the "excess").** The large total you might have imagined
   is **not pre-minted** — it's just unminted headroom held conceptually by the
   treasury. Its earmark: **seed AMM liquidity once a prediction market
   launches**, giving STR external utility (betting/hedging/cashing out).

### Mint vs sink (avoid runaway inflation)
Settlement mints; these are the sinks that balance it:

| Mint (+) | Sink / recycle (−) |
|---|---|
| settlement finish bonus | exam **20 % fee → treasury** |
| | exam fees locked while in flight |
| | slashed leader bonds → pool / treasury |
| | **prediction-market fees / spread → treasury** (future) |

The **prediction market** is the key sink *and* the demand engine — it turns STR
from an in-project accounting token into an asset worth holding. It's a **future
extension**, not in the current build plan; the treasury reserve is its runway.

### Treasury & policy
### Prediction-market guard (forward-looking, do this now)
The fear "the future prediction market will devalue STR" inverts the causality:
**pre-inflating supply now is what would devalue it.** Guard rails:
- **Never pre-mint for the prediction market.** Supply stays elastic + work-
  backed; the market is funded from the **treasury reserve**, not new mint.
- **Make the market redistributive** (peer-to-peer: winners paid from losers,
  treasury takes only a fee) → zero inflation, and it *creates* demand for STR.
- **Scale denomination, not supply.** Keep STR accounting **decimal** (DB is
  already `numeric`; just let the UI show decimals) so fine-grained odds / bets /
  fees work at any supply. If integer granularity ever bites, do a
  **value-neutral redenomination** (split), never an issuance.

- **Treasury account** — a real `stater` account that collects exam fees,
  slashed bonds, and holds the reserve.
- New policy keys: `genesis_float`, `finish_bonus_ratio` (base, default 1.0),
  `milestone_multiplier_cap` (default 3.0), `exam_fee_treasury_cut` (0.2).
  Per-milestone `multiplier_bonus` lives on the milestone catalog (§4b), not as
  a flat step. Final mint multiplier =
  `min(finish_bonus_ratio + Σ verified.multiplier_bonus, cap)` (§4b).

## 1. One concept: contribution = minted stake

We used to conflate two things under "staking." They are now unified for
contributors and kept distinct only for the leader's accountability bond.

| Who | What they put in | How it becomes stake | Slashable? |
|---|---|---|---|
| **Contributor** | **20 STR join bond** + labor (hrs/mo) and/or resources | bond is real STR into escrow **and** seeds nominal claim; labor/resources **valued → minted into nominal STR**, monthly | **yes** — bond slashed if they flake; unminted months simply don't mint |
| **Leader** | **50 STR cash bond** **+** first authorship **+** monthly hours | bond is real existing STR; hours mint like anyone's | **yes** — bond slashed if they flake |

Both bonds are real liquid STR that **fund the pool** and **seed the holder's
nominal claim** (the 20 / 50 counts toward their weight). Contributions
(minted nominal) then decide the split on top.

> **Contributions mint the pool. The joint settlement decides the split.**
> A contributor's "skin in the game" *is* their minted work — show up and it
> mints, don't and it simply doesn't. The leader alone carries a slashable cash
> bond because the leader is accountable for the whole project.

## 1b. Nominal STR vs liquid STR

Minting creates **nominal STR**, not liquid STR. Labor and resources both mint
this way.

| | **Nominal STR** (minted) | **Liquid STR** |
|---|---|---|
| Origin | declared labor/resources, valued | already in your wallet |
| Lives in | **locked in the project pool** | circulating balance |
| Can do | **only fund this project** — not transferable/spendable/cross-project | freely spendable (the leader's 50 bond is liquid STR) |
| Becomes real | at **settlement sign-off**, the agreed share converts to liquid STR | — |

So **mint = write nominal STR into the project pool** (an in-project bookkeeping
claim, provisional until settlement, doesn't touch circulating supply).
**Settlement = convert your agreed share of the pool into liquid STR** in your
wallet (+ finish bonus). Declare-and-mint is therefore safe: no inflation of
circulating supply, and no one can mint nominal STR and cash it out elsewhere
before delivering — under-delivery just converts to little/nothing at
settlement. The leader's 50 is *liquid* STR locked in escrow, which is precisely
why only it is slashable (real downside; nominal STR is worth nothing until
settlement).

UI: the wallet shows **liquid balance** separately from **nominal STR locked per
project**. Data: nominal STR does not enter `stater_balance`'s circulating
balance — it accrues on the project pool / commitment; only settlement runs a
real `stater_move` into the wallet.

## 2. Contribution = one concept, several flavors

A contribution is *something of value a member commits to a project*, valued in
STR and **minted into the project pool as nominal staked STR** (§1b). Labor is
just the labor-typed resource.

| Flavor | Capacity unit | Valuation (= minted STR) | Cadence |
|---|---|---|---|
| **Labor** (a member's time) | **hrs / month** | `hours × skill_rate` | monthly, adjustable |
| Compute | GPU-hrs / month | steward-set token-equiv | monthly, adjustable |
| Funding | $ | steward-set token-equiv | once or monthly |
| Data / equipment | lump | steward-set token-equiv | once |

### Rolling monthly commitment (confirmed)
Commitment is **not** fixed at join. Each month a member declares what they'll
put in for the coming month — that's the amount that participates in next
month's minting. Adjust up when free, down (or to 0) when busy; no need to quit
and rejoin.

```
declare month m:  committed_hours[m]   (and/or resources)
mint month m:     committed_hours[m] × rate   → minted into project pool
accrued (to date) = Σ_m ( committed_hours[m] × rate ) + Σ resource mints
```

**Declare = mint**: declaration mints immediately into the pool (trust-based,
no monthly verification gate). The truth check lives at settlement (§4), where
the leader + community can discount anyone who declared but didn't deliver.

## 3. Roles

| Role | Backing | Core want |
|---|---|---|
| **Contributor** | any member | Find a project, pledge monthly time/resources, mint a fair share |
| **Leader** | `project_member.can_manage` | Post the 50 bond, take first authorship, assemble a team, ship, draft the split |
| **Resource steward** | `manage_resources` | Vet pledged resources/labor so offers (and their valuations) are real |
| **Stater manager** | `manage_stater` | Co-settle with the leader; keep the economy honest |
| **Org admin** | president | Invite members, set taxonomy + economic policy (rates, leader bond) |

## 4. Lifecycle as role-framed stories

### Proposal (立项)
- **Leader**: create project, **post the 50 STR cash bond**, commit to **first
  authorship**, pledge own monthly hours, set target venue/deadline, post
  **needs**. A need asks for a *contribution*: e.g. *Labor — 40 hrs/mo of NLP
  (≥ Advanced)*, or *Compute — 200 GPU-hrs/mo*.
- Any member may also **claim a leaderless project** by posting the 50 bond
  (already shipped: `claim_leadership`).
- **Contributor**: browse Opportunities, apply to a need with a pitch.

### Data collecting / Work in progress (进行中)
- **Contributor**: accepted → **join by posting the 20 STR bond** (real, into
  escrow; seeds nominal claim) **and** registering the contribution. Each month,
  **set next month's hours/resources**; declaration **mints immediately** into
  the pool. Accrued mint ticks up monthly.
- **Leader**: see live roster with each person's *this-month commitment* and
  *accrued minted value*; close/adjust needs.
- **Steward**: approve member resources/labor and their valuations so what gets
  minted is real (approval gate already drafted).

### Under review (评审)
- **Leader**: freeze commitments; **draft the settlement**. Payout weights are
  **pre-filled from accrued minted value** + authorship (first author = leader),
  and the leader can **adjust down** anyone who declared but didn't deliver.
- **Stater manager**: review the draft, adjust if needed.

### Finished (结算)
- **Leader + Stater manager**: **co-settle** — both sign. On approval the
  **project pool** (everyone's minted contributions + the leader's bond) plus a
  **minted finish bonus** is distributed by the jointly-agreed weights.
- **Leader bond**: folded into payout if delivered; **slashed** (kept in pool
  for the finishers) if the leader flaked.
- **Contributor**: minted share converts to payout; sees the wallet
  celebration.

## 4b. Milestones = outcome minting (reuse whitepaper §13 / §20.2)

The pool grows along **two axes**: *input* (monthly labor/resource minting, §2)
and **output** (milestones). A milestone is a verifiable achievement; verifying
it mints nominal STR into the pool. Together they stop pure time-logging from
dominating — milestones decide *how big the pie is*, contributions decide *the
slices*.

**Don't reinvent — reference the Stater whitepaper, already defined:**
- **§13 milestone catalog**: 8 categories (submission, acceptance, release,
  open_source_impact, huggingface_impact, community_signal, benchmark_result,
  governance) with example items, and a status machine
  `claimed → under_review → verified → rejected/expired/revoked`. **Only
  `verified` milestones mint** (this is the milestone gate — unlike monthly
  hours which are trust-based; an outcome claim must be verified).
- **§20.2 milestone bonus price table**: arXiv 20, submitted 30, accepted 100,
  top-venue 200, dataset/model 50, SOTA 150, … (per-project-type templates per
  §12).
- **Distribution = Option A (confirmed)**: whitepaper says *"milestone bonus
  goes to project escrow, not directly to individuals"* → it enlarges the
  **pool**, split at settlement by the **overall accrued weights** (no
  per-deliverer attribution).

### Dual effect — milestones both add nominal AND raise the mint multiplier
A verified milestone does **two** things:
1. **Adds nominal STR** to the pool (its §20.2 value) → grows everyone's
   shareable nominal.
2. **Bumps the settlement mint multiplier** by a **per-milestone-type amount set
   on the catalog** (each §13/§20.2 item carries its own `multiplier_bonus`,
   e.g. arXiv +0.5 %, submitted +1 %, accepted +5 %, top-venue +10 %, SOTA
   +8 %, dataset +2 %). Admin-configurable like the §20.2 value table.
   **Capped at ×3** (`milestone_multiplier_cap`, default 3.0).

So each milestone in the catalog has **two configurable fields**: a
`nominal_value` (§20.2) and a `multiplier_bonus`. At settlement:
```
nominal_pool = bonds(20/50) + labor mints + resource mints + milestone nominal
mult         = min( 1 + Σ verified_milestones.multiplier_bonus , 3.0 )
real finish mint = nominal_pool × mult − escrowed bonds   (bonds already real)
payout_i     = nominal_share_i × nominal_pool × mult       (+ bond returned)
```
So milestones **make the pie bigger (nominal) and raise the conversion rate
(multiplier)** at once, capped ×3 to deter gaming (whitepaper §26.5). A project
with no milestones → thin nominal, ×1 → labor converts at face value only.

**Already scaffolded in `stater.sql`** — reuse, don't re-add: ledger
`entry_type='milestone_bonus'`, `stater_ledger.milestone_id`, and
`stater_project_participant.milestone_contribution_score`.

**Flow**: Leader/contributor **claims** a milestone from the catalog →
reviewer (steward/Stater) marks **verified** → mints the table's STR (nominal)
into project escrow via `milestone_bonus`. Anti-gaming per whitepaper §26.5
(admin can revoke; reduce/pause on abuse).

**Delta to build**: a `project_milestone(project_id, category, item, value,
status, claimed_by, verified_by, verified_at)` table (the ledger hooks exist;
the catalog/claim table does not yet). Milestone value seeded from the §20.2
table / project-type template, leader may propose, verifier confirms.

## 5. Data-model deltas (proposed)

Reuses `stater_project_stake_commitment` (`commitment_type`, `skill_id`,
`resource_id`, `hours_committed`, `token_amount`, `token_equivalent`).

1. **Add a `Labor` resource type** (seed); a member's time is a resource they
   hold: `resource(type=Labor, holder_member_id=…)`.
2. **Rolling commitment = parent + monthly periods.**
   - `commitment` is the standing pledge (kind: labor | resource).
   - `commitment_period(commitment_id, year_month, committed_amount,
     status: declared | minted)` — one row per month. `declare = mint` so a
     declared row mints right away; accrued = Σ minted rows.
3. **Rename `skill_time` → `labor`** conceptually (valued at `hours × rate`).
4. **Needs become contribution-typed**: `open_need.contribution_kind`
   (`seat | labor | resource`) + `hours_per_month`, so a need can ask for
   monthly hours or a resource.
5. **Two bonds, both real + slashable.** Contributor join bond
   (`join_stake`, 20) and leader bond (`leader_stake`, 50): real liquid STR into
   escrow that fund the pool and seed the holder's nominal claim.
6. **Settlement is joint + adjustable**: `submit_settlement` (leader) pre-fills
   weights from accrued mint, leader can adjust; `approve_settlement` (Stater
   manager) co-signs; both required to finalize.
7. Approval gate (`resource_approval.sql`) also covers labor pledges and their
   valuations (labor is a resource).

## 6. Bond / mint model — DECIDED

- **Contributor: 20 STR join bond, slashable.** Real liquid STR into escrow —
  it **funds the pool** and **seeds the holder's nominal claim** (counts 20
  toward their weight). Anti-flake is *double*: the bond can be slashed, and
  unworked months simply don't mint.
- **Leader: 50 STR cash bond, slashable.** Plus first authorship + monthly
  hours. Same mechanic, larger, accountability-bearing.
- **Nominal pool** = Σ contributor bonds (20) + Σ leader bonds (50) + Σ labor
  mints + Σ resource mints + Σ verified milestone nominal (§4b). At settlement
  it's scaled by the **milestone multiplier** `min(1 + verified×1 %, ×3)` and
  converted to liquid STR by nominal weight (§4b).
- **No monthly verification gate for labor** (declare = mint, trust-based).
  Milestones *are* verified before minting (§4b). The single split-level truth
  check is the **joint settlement** (§4): leader drafts (can discount
  non-delivery), Stater manager co-approves, both sign.
- Policies unchanged: `join_stake` 20, `leader_stake` 50. A flaker's bond stays
  in the pool for the finishers. New members afford bonds via the welcome grant
  (§0 / whitepaper §14.1, 100 STR).

## 7. Build plan (on green light)

1. **DB migration `contributions.sql`**
   - Seed a `Labor` resource type.
   - `open_need.contribution_kind` (`seat | labor | resource`) +
     `hours_per_month`.
   - `commitment_period(commitment_id, year_month, committed_amount, status)` —
     monthly rows; `declare = mint` writes the row + mints into the project pool.
   - `confirm_join` (contributor): **charge the 20 join bond** (real STR into
     escrow, seeds nominal claim) + register the standing commitment and open
     the current month's period (declare = mint). [Reuses existing `join_flow`
     bond logic — keep it.]
   - `set_commitment(month, amount)`: a member sets next month's
     hours/resources; mints immediately.
   - `leader` entry (create / `claim_leadership`): charge the 50 bond, record
     first-author + the leader's monthly labor commitment.
   - `accrued_value(commitment)` = Σ minted periods; drives both minting and
     settlement seed.
   - **Milestones (§4b)**: a **`milestone_catalog`** (category, item,
     `nominal_value`, `multiplier_bonus`) seeded from whitepaper §13/§20.2 +
     per-project-type templates, admin-editable; plus `project_milestone`
     (claim + status, references a catalog item). `verify_milestone` (a) mints
     `nominal_value` as `milestone_bonus` nominal into pool **and** (b) the
     project's multiplier accrues that item's `multiplier_bonus`. Reuse
     `milestone_id` / `milestone_contribution_score` hooks.
   - `submit_settlement` / `approve_settlement` apply
     `mult = min(finish_bonus_ratio + Σ verified.multiplier_bonus, cap)` to the
     nominal pool when minting the real finish bonus.
   - `submit_settlement` (leader draft, pre-filled + adjustable) +
     `approve_settlement` (Stater co-sign); both required.
   - Slash applies only to the leader bond.
   - Folds in `resource_approval.sql` (labor pledges + valuations are resources
     → steward-approved before they count).
2. **Project detail → role-framed sections** (leader / contributor / steward,
   phase-aware). **Keep base attributes** (status stepper / target venue / ddl);
   **add** pool panel (nominal, multiplier, escrow), milestone rail, roster
   (this-month commitment + accrued + share %), "My contribution" panel with a
   **set-next-month** control, joint-settlement panel.
2b. **Projects list → market board**: **keep** name / phase / venue / ddl;
   **add** nominal pool, multiplier ×, milestones ✓n/m, open needs by kind
   (labor/resource), ⚑ claimable (leaderless). Sortable by pool / multiplier /
   activity.
3. **Opportunities → task market**: needs typed **hours/month vs resource**
   (skill + guild level + join bond), filterable by kind/skill/level; leaderless
   projects listed as "claim leadership (50 bond)".
4. **Leaderboard → multi-board** (tabs): 💰 Wealth (liquid), 📊 Net worth
   (liquid+nominal), ⚒ Contribution (lifetime minted) [**default**], 🏅 Masters
   (certified/Master count). Clarify existing "balance" = liquid; add nominal.
5. **Profile (`/profile`, private/editable)** — labor pledge surfaced alongside
   resources (medals already built; resources gated by approval). Owner-only:
   wallet balance + ledger.
5b. **Public member page (`/members/[id]`, read-only)** — reputation, not
   finances. Shows: name/affiliation, certified skill medals + **Master** crowns,
   approved resources offered, project history (role / first-author / milestones),
   lifetime contribution mint, milestones, endorsements. Others can endorse a
   skill or (if this member is a skill Master) view rubric / request an exam.
   **Privacy line: never show liquid balance or ledger publicly** — financial
   privacy; reputation = contribution/certs/milestones, not wallet size. Linked
   from leaderboard rows, endorsers, roster names.
6. **Settlement** — leader drafts (pre-filled, adjustable) → Stater co-signs.
7. **DB migration `skill_exam.sql`** (§8) — `skill.author_member_id` +
   `skill_exam_rubric`; `member_skill.certified_level/_at`; `skill_exam` +
   `skill_exam_vote`; policy `skill_exam_fee_*`; RPCs `request_skill_exam`
   (escrow fee, random-assign 3 qualified reviewers ex-self), `cast_exam_vote`,
   `settle_exam` (majority → certify; distribute 80/20 regardless of outcome).
8. **Skill exam UI** — profile medal "Take exam" + "✓ certified" badge; skill
   author gets a "Design rubric" editor; reviewer queue to grade against rubric;
   `/skills` tree browser + branch-sub-skill.
9. **Admin → STR economy panel** (§0 oversight & monitoring)
   - **Supply at a glance**: total liquid supply, total nominal locked (by
     project), treasury balance, genesis float remaining.
   - **Flow over time**: minted (settlements) vs sunk (exam fees, slashes) — a
     mint/sink ledger and a running net-supply line.
   - **Policy knobs**: `genesis_float`, `finish_bonus_ratio`,
     `exam_fee_treasury_cut`, `leader_stake`, `skill_exam_fee_*` — editable.
   - **Treasury ledger**: every fee/slash inflow, reserve earmarked for the
     future prediction market.
   - **Health flags**: inflation rate (minted/period), concentration (top
     holders), stuck escrows (long-open projects).

## 8. Skill exam economy (paid, peer-reviewed certification)

Skills go from *self-declared* to *certified* via a paid exam graded by peers
who already hold the skill. This makes skills a self-sustaining labor market:
experts earn STR by reviewing, newcomers buy credible certification, the system
takes a cut.

### Skill author (cold start, confirmed)
The **first member to hold a skill is its author**: they design the exam
requirements (a rubric, per level), and are **auto-certified at the top level**,
seeding the qualified-reviewer pool for that skill. No admin anointing needed —
whoever picks up a skill first defines how it's tested. (Org admin may curate.)

### Levels — guild ladder (confirmed)
The level ladder is a craft-guild progression that ends in **Master**:

```
Apprentice (学徒) → Journeyman (职人) → Craftsman (名匠) → Master (宗师)
```

The **Master** of a skill owns its rubric, is a qualified reviewer, takes
apprentices, and may branch sub-skills (see §9). Replaces the old
`Beginner/Intermediate/Advanced/Expert`.

### Fee by level (policy)
`skill_exam_fee_{apprentice,journeyman,craftsman,master}` — higher level, higher
fee, e.g. 5 / 10 / 20 / 40 STR. Paid in **liquid STR**.

### Flow
1. **`request_skill_exam(skill, level)`** — applicant pays the level fee (liquid
   STR) into escrow.
2. **Random assignment** — system picks **3 qualified reviewers** at random:
   certified in this skill at **≥ target level**, **excluding the applicant**.
   (Author counts as qualified.)
3. **`cast_exam_vote(exam, pass|fail)`** — each reviewer grades against the
   author's rubric.
4. **`settle_exam`** — **majority rule**: **≥ 2 of 3 pass → certified**.
   - **Fee distributes regardless of outcome** (decision: reviewers are paid for
     their labor; an exam is pay-to-sit, not pay-only-if-pass — this also deters
     lazy/retaliatory fails): **80 % split among the 3 reviewers, 20 % system
     fee to treasury**.
   - **On pass**: skill medal marked **"✓ certified <level>"** + a credit boost.
   - **On fail**: no certification; applicant may retake (pay again).

### Reconciliation with existing signals
- `stater_skill_credit` (lightweight peer endorsements, bronze→silver→gold)
  **stays** as a soft popularity signal.
- The **paid exam is the hard credential**; a certified medal outranks an
  endorsed one. Only **certified** holders (≥ level) can review.

## 9. Skill tree — guild growth model

Skills form a **tree grown by Masters**, not a flat tag list or a one-time
admin taxonomy.

### Structure
Nodes nest **domain → branch → concrete skill (leaf)**, e.g.

```
NLP
├─ Information extraction
│   ├─ Named-entity recognition   ← leaf (examinable)
│   └─ Relation extraction
└─ LLMs
    ├─ Pretraining
    └─ Alignment / RLHF
```

### Exams happen at the leaf (confirmed)
You sit an exam for a **concrete leaf skill** at a chosen guild level. A
non-leaf/domain mastery is conferred by **holding Master in enough of its
children** (auto-rolled-up), not by a vague exam on the whole domain.

### Masters grow the tree (confirmed)
- A skill's **Master** (= first to reach Master / its author) **may branch new
  sub-skills directly** under their node, and author/become Master of the child.
  No approval needed — fast organic growth. (Org admin may later merge/curate.)
- This makes the taxonomy a living tree of master→apprentice lineages: whoever
  masters a craft earns the right to subdivide it and define how the next layer
  is tested.

### Data
`skill.parent_id` already exists. Add `skill.master_member_id` (author/Master)
and `skill_exam_rubric(skill_id, level, requirements)`. A `branch_skill` RPC
lets a Master create a child node.

## 10. In-flight work to reconcile
- **Skill medals** (profile) — built, **uncommitted** → now committed (06a5d7a).
- **Resource approval** (`resource_approval.sql` + admin queue) — built,
  **not applied to live DB**. A *dependency* of this plan (labor pledges +
  valuations need the same gate), so it lands as part of step 1's migration.
