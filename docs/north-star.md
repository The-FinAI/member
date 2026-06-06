# North Star — Target Architecture & Vocabulary

*The decisive target. Not analysis — this is what the rebuilt product **is**. Everything
else (PRD-hci.md §1–13) is the reasoning; this is the answer. Designed from HCI: it maps
1:1 to how a researcher thinks, uses one word per concept, and one pattern per action.*

---

## 1. The product in one sentence

**The Fin AI Community turns research collaboration into a settled STR economy:**
people **contribute** to **projects**; finished projects **settle** into spendable STR.
*(Phase 1: officers operate on behalf of members who can't log in yet.)*

That sentence is the whole information architecture. Every screen serves it.

---

## 2. The object model (the only nouns users meet)

```
   Person ──seated on──▶ Need ──on──▶ Project ──achieves──▶ Milestone
     │                                   │   (boosts payout)
     └──── contributes ────▶ Contribution│
              (hours / resource, valued in STR)
                                         ▼
                                    Settlement ──pays──▶ STR
```

| Noun | One line | Canonical term |
|---|---|---|
| **Person** | a researcher; in P1 a **card** an officer manages | *Person / Card* |
| **Project** | the unit of work, toward a publication | *Project* |
| **Need** | an open role on a project: a skill (at a level) **or** a resource | *Need* |
| **Contribution** | what a person commits monthly: hours-of-a-skill or a resource, valued in STR | *Contribution* |
| **Skill** | a capability at a **level** (Beginner→Expert) | *Skill* |
| **Resource** | compute · data · funding · people-time a person holds | *Resource* |
| **Milestone** | an achievement (submission, acceptance, release) that grows the payout | *Milestone* |
| **STR** | the credit: **nominal** (accruing, locked) → **liquid** (spendable) | *STR* |
| **Chapter** | a group that stewards **people** | *Chapter* |
| **Group** | a working group that stewards **projects** | *Group* |

Six nouns do all the work: **Person, Project, Need, Contribution, Milestone, STR.** If a
feature can't be said with these, it probably doesn't belong.

---

## 3. The architecture (surfaces — role-filtered)

**Primary (the work):**

| Surface | Purpose (1 line) | Primary object |
|---|---|---|
| **Home** | your STR, loop status, the one next action | you |
| **Projects** | the work & the STR engine — browse · create · run a project | Project |
| **Console** *(officers)* | the workbench: match your people ⟷ open needs, seat in place; run your projects | Person ⟷ Need |
| **Wallet** | your STR (nominal + liquid) and how you earn it | STR |

**Secondary (reference & governance):**

| Surface | Purpose | Who |
|---|---|---|
| **People** | directory of researchers, chapters, groups | everyone |
| **Admin** | one Review queue + Settings (economy · skills · roles · catalog) | admins |
| **Guide** | help (a link, not a workspace) | everyone |

That's **4 + 3**, down from 41 routes. A member in P2 sees the same shell with member data
(no Console).

---

## 4. The roles (one small, legible set)

| Role | What they are | What they do |
|---|---|---|
| **President** | org owner | full authority; governs the economy |
| **Officer** *(of a unit)* | **Chapter Chair / Secretary** (stewards people) · **Group Lead** (stewards projects) | the P1 operators |
| **Researcher** | a member | contributes; in P2 logs in & acts for themselves |

Permissions are shown as **named groups**, never raw keys:
**Approve credentials · Manage people & access · Manage projects · Manage skills & catalog ·
Manage resources · Run the STR economy.**

*(Deleted: Board / Steering / Executive ladder, and the parallel apply-to-unit membership —
in P1 officers **place** people, members don't apply.)*

---

## 5. The lifecycle (this IS the pipeline)

```
Proposed ─▶ Active ─▶ Under review ─▶ Finished ─▶ Settled        (＋ On hold)
 recruit    contribute    polishing    settle →    STR paid
```

One status vocabulary drives the project page's pipeline, the cockpit's "next action", and
the worklist. (Merged the old *Data Collecting* + *Work in progress* → **Active**.)

---

## 6. The vocabulary (canonical — one word per concept)

| Concept | Term (EN) | 中文 | Replaces (banned) |
|---|---|---|---|
| the credit | **STR** | STR | Stater, token |
| accruing, locked | **nominal STR** | 名义 STR | staked |
| spendable | **liquid STR** | 流动 STR | — |
| create | **Add / Create** | 添加 / 创建 | Forge, mint |
| an open role | **Need** | 需求 | slot, open_need |
| place a person on a need | **Seat** | 入座 | bind, commit, stake |
| a person's monthly commitment | **Contribution** | 贡献 | commitment_period |
| pay out a finished project | **Settle** | 结算 | harvest, payout |
| skill proficiency | **Beginner · Intermediate · Advanced · Expert** | 初级·中级·高级·专家 | Apprentice…Master, guild |
| the skill catalog | **Skills** | 技能 | Guild |
| achievement that grows payout | **Milestone** | 里程碑 | — |
| approvals list | **Review queue** | 审核队列 | Forge queue |
| a person record (P1) | **Card** | 卡片 | skillcard |
| people-stewarding unit | **Chapter** | 分会 | — |
| project-stewarding unit | **Group** | 工作组 | WG, working_group (spell out) |
| author roles | **First / Co / Corresponding author** | 第一/合著/通讯作者 | — |

**Rule:** the same word in nav, buttons, copy, admin labels, and tooltips. No synonyms.

---

## 7. The components (one of each, everywhere)

- **Card** — `[type] [status pill]` / title / subtitle / `[metric] [one action]`. One for
  Person, Project, Need.
- **Detail** — wide = drawer (peek + the one relevant action); narrow = the route page
  (deep edit). Never a drawer-in-drawer or a tab-app in a drawer.
- **ActionSheet** — a focused, in-place form for one action (seat, post need, settle).
- **SkillTree** — the single skill+level picker (domains → leaf skills → 4 level pips),
  used for badges, member add, needs, resource skills, admin defaults. Read-only = filled pips.
- **ResourceForm** — the one type-adaptive resource declarer (have it).
- **Pipeline** — the lifecycle stepper on the project + cockpit.
- **ReviewItem** — one row of the Review queue, showing its actual content.
- **Cockpit** — the home hero (have it).

---

## 8. What disappears (the cull)

- **6 dead backend subsystems** (token economy, apply→accept→confirm join, stake
  commitments, skillcards, skill-exam + endorsement, resource offers, paid-leader bonds) →
  one **legacy-purge** migration.
- **~15 legacy admin routes** → folded into the 5 consoles + Review queue.
- **Dead components** (`Matcher`, `SlotBoard`, `CardBinder`, `MemberCard`, `GettingStarted`).
- **Jargon** (Forge, slot, guild, harvest, miner, Stater) → §6 vocabulary.

Target: **~12 routes · ~20 components · 6 nouns · 1 word per concept.**

---

## 9. The test for any future change

> Can it be said with the six nouns, named with the one vocabulary, reached on one of the
> seven surfaces, and done with one card/detail/action pattern? If it needs a new noun, a
> new word, a new surface, or a new interaction pattern — it's probably wrong, or something
> else must be removed.
