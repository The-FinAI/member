# The Fin AI Community — The System (clean-slate PRD)

*Designed from our logic alone. **Not** a migration of what exists, **not** a list of deltas, **not** a
de-risked rollout of the current build. This is what the system **is**. Where today's code conflicts with
this, today's code is wrong. The reasoning trail lives in `redesign-hci.md`; this is the destination.*

---

## 0. The two decisions everything else follows from

> **STR is the *goal*. A true, daily-used *record* is how STR becomes real.**

These are not in tension — they are sequential. The community's purpose **is** the STR economy: turning
research contribution into settled, spendable credit. But an economy can only settle what it can
**measure**, and it can only measure contribution if the community's real work — projects, people, tasks,
hours — actually **lives in the system** instead of in a Google Doc. So:

1. **STR is the spine, kept legible and quiet — never cut.** Every logged hour, every finished project
   feeds the ledger; contribution accrues as **credit**; finished work **settles** into spendable STR.
   This is the reason the product exists. What we *don't* do is make a **mining/wallet dashboard the
   officer's home** — STR is shown **where it becomes meaningful** (a person's accruing contribution, a
   project's pool, the Finish→Split moment, the wallet) and stays **out of the way of the daily record**.
   *Legible and quiet, not absent.*
2. **The record is what makes the economy true.** If the WG runs on this instead of its doc, every hour
   and task is captured — and STR settles on **real data**. A record nobody keeps = an economy measuring
   nothing. So we win the record first, and STR rides on it, visible at the moments it matters.

The Phase split restated: **Phase 1** — officers run the record; STR accrues, legible but quiet (it is
*their proxies'* credit, not the officer's hero number). **Phase 2** — members log in; **STR becomes the
member's hero** (my contribution, my wallet, settle). *Same ledger, the spotlight moved onto it.*

Everything below is the minimal system that captures the work **and** lets STR settle honestly on it.

---

## 1. The model — six things, and only six

```
Unit ─┬─ Chapter ─── Person ──< has >── Skill @ {Learning|Independent|Lead}  + evidence (from the record)
      │                 │  capacity: hours / month (time-phased)
      │                 └──< member of >── Project   (a Membership: role, hours, since)
      └─ Working Group ─ Project ─┬─ Need   (formation: a Skill @ desired level | a resource + capacity)
                                  ├─ Task   (execution: group? · name · skill(=work-type)? · owner? · state · note)
                                  └─ Milestone
```

| Thing | One line |
|---|---|
| **Unit** | a **Chapter** (contains people) or a **Working Group** (contains projects). The two domains. |
| **Person** | a researcher (P1: a card a chapter steward manages). Has **skills** (each at a **behavioral level** — Learning / Independent / Lead — **backed by evidence from the record**, §3.1) and **capacity** (hours/month, shown per period). |
| **Project** | work toward a publication, owned by one WG. Identity (emoji · code · title) · status · links (Proposal/Arxiv/References) · body · **team** · **tasks** · **milestones**. |
| **Need** | what a project requires to **form**: a **skill @ desired level**, or a resource, with a capacity & headcount. Filled by **matching** → creates a Membership. Level is a *soft sort signal*; capacity is the hard gate. |
| **Task** | the **execution** unit: `{group?, name, skill(=work-type)?, owner?(TBD=open), state, note}`. Assigned **directly**. |
| **Membership** | a Person on a Project: their role, monthly hours, since-date. The source of **contribution** (hours), which the ledger values in **STR**. |

Plus reference lists: **Skill** (a flat shared list — one vocabulary used three ways: a person's tag, a
task's work-type, a Need's descriptor), **Milestone type**, and the **STR ledger** (contribution →
accruing credit → settled, spendable STR). STR is the **value layer beneath** the six nouns — every
logged hour feeds it — but it is *shown* only at the moments it means something (§4.4, §4.5, the wallet),
never as the daily surface. ~7 core tables.

**Skill level (redesigned from HCI — see `redesign-hci.md` §15).** Not an abstract 4-tier ladder, not a
badge tree, not a certification queue. Three **behaviorally-anchored** levels, each = *what work can I
trust them with*: **Learning** (contribute with guidance) · **Independent** (own a task end-to-end) ·
**Lead** (set direction, guide others). Every level is shown **with evidence auto-derived from the
record** — `Annotation · Independent · 4 tasks · 2 shipped` — so the record *is* the certification (no
reviewer, no provenance machinery). Declared in one tap; the system **suggests raises as evidence
accrues** ("owned 5 annotation tasks → mark Independent?"). Used to **rank** candidates in matching,
**never to exclude** them.

---

## 2. Two logics, one lifecycle

A project moves through two logics, in order — both first-class, never conflated:

```
 Propose ──▶ FORM (resource matching) ──▶ RUN (direct task work) ──▶ Finish ──▶ Settle (Split → STR)
   create        post Needs · match            task board · owners        close       contribution → credit,
   the project   people by skill+capacity      assigned directly          the work    split & paid in STR
```

*Throughout, contribution (logged hours) accrues into the STR ledger silently; STR becomes **visible**
at Settle, on a person's profile, and in the wallet — not on the daily task board.*

- **FORM = matching.** The project declares **Needs**; a chapter steward matches **People** to them by
  skill, **level + evidence** (a soft rank), and **spare capacity** (the hard gate). Output: the **team**.
  A project doesn't run until it's resourced.
- **RUN = the living record.** The team works **Tasks**; the lead assigns **owners directly** (a
  teammate, or TBD), tracks status, keeps coverage checklists, links, prose. **This is the thing that
  replaces the Google Doc** — and it is the product's daily heartbeat. Every hour logged here is what the
  STR ledger later settles on.

**Need ≠ Task.** Matching produces the team; tasks organize the team's work. Different objects, different
stages. And the record those tasks form is **the ground truth the economy settles on** — no record, no
honest STR.

---

## 3. Surfaces — four, period

| Surface | Who steers | What it is |
|---|---|---|
| **Projects** | WG steward (everyone browses) | **The living record.** Every project as its doc-section: task board · coverage · links · body · team · status. The main surface. |
| **People** | Chapter steward (everyone browses) | The **roster** (skills + capacity bars) and the **matching** board that fills forming projects' Needs. |
| **My** | everyone | My projects, **my tasks across all of them**, my profile/skills, **my contribution & wallet** (STR — quiet in P1, the **hero in P2**). |
| **Settings** | admin | Catalogs (the shared **skill list** · project types · milestone types · units & stewards) · the **economy** (rates, settlement review) · the few real approvals. |

**Home is not a surface — it is a router** that drops you into your domain with a **"what needs me"**
list on top: *WG steward* — "X finished → settle · a Need is fillable · 3 tasks unowned"; *Chapter
steward* — "2 Needs your people fit · 1 person freed up." A dual-role person sees **two clean surfaces**,
never a blended one. **STR lives on My and at Settle — not on the home, not on the task board.** No
mining console, no wallet-hero home, no leaderboard, no forge queue.

---

## 4. The flows that define the product

**4.1 Run a project (the heartbeat) — replaces the doc.** Open a project → its **task board**
(`Task · Type · Owner · Status · Note`, inline-editable; add a row; assign an owner or leave TBD; click a
cell to change state) · **coverage** groups (e.g. language × state × owner) · **links** (Proposal · Arxiv
· References) · **body**. Cross-project views the doc can't give: **all open/TBD tasks in the WG** (the
backlog), **my tasks everywhere**, by owner, what changed this week.

**4.2 Form a project — matching (default) with a direct override.** Create (emoji · code · type ·
proposal) → post **Needs** (a skill at a *desired* level, or a resource, + capacity), each showing the
**candidate-pool size** so demand isn't blind.
- **A — matched assign (the default, the ecosystem engine):** on the People surface, select a person →
  fitting Needs glow with their **spare capacity**, **level + evidence**, and **why they fit** → click →
  confirm pre-filled to min(free, need) → **Assign**. Candidates are **ranked** by level/evidence/
  capacity; under-level people still show (capacity is the only hard gate). Select→glow→click is primary.
- **B — direct override (name-and-go):** a lead who already knows who they want searches a person and
  **assigns directly**, bypassing the ranking. Capacity is still the hard gate; level/skill just don't
  filter. Always available from any Need.

The system **guides toward A** — matching is what makes the community an ecosystem (it surfaces
who-can-do-what, creates demand signals, lets people grow into levels, and gives STR its meaning) — but
**never forces it**; B is one search away.

**4.3 Register & steward people.** Add a card: name · email · affiliation · **hours** · skills. A skill =
pick a tag + set **Learning / Independent / Lead** in one tap (plain words, no pip-tree, no review). The
level shows **with its evidence from the record** (`4 tasks · 2 shipped`); as evidence grows the system
**suggests a raise**. Own-roster edits apply **immediately, with undo**.

**4.4 Finish & Settle (Split → STR).** Mark finished; contribution (logged hours) is sealed. The **Split**
view distributes the project's pool: each contributor's weight **defaults to their logged hours**, with a
**fairness summary** (shares = 100% · flags "big contributor, tiny share") and contribution history
beside it; authors/corresponding marked; submit → review → **STR paid**. This is the moment STR is loud
and central — the payoff the whole record was building toward. *(In P1 the officer settles on the
proxies' behalf; in P2 the member sees their own STR land.)*

**4.5 STR, where it lives.** A person's profile shows **contribution accruing** (credit so far); the
**wallet** (My) shows accruing vs settled STR with a one-tap "how it's computed" (hours × rate); a
forming project shows its **projected pool**. Everywhere else — the task board, the roster, the home —
STR is **absent by design**, so the daily record stays about the work.

---

## 5. Interaction — the Definition of Done for every screen

Non-negotiable; a screen that violates these is unfinished (full rationale & precedents in
`redesign-hci.md` §11/§13):

1. **Two domains never share a screen** — they meet only at the Need.
2. **One concept = one word = one component = one gesture.** No duplicate forms, no synonyms.
3. **Direct manipulation:** select → only-valid-targets glow → click. Matching and assignment both.
4. **Constraints visible before they block:** capacity is a **time-phased bar**; no silent-greyed
   button — **enabled with the one blocking reason + the fix, at the field.**
5. **No reload-everything:** acts update **optimistically in place**; scroll, selection, open pickers
   **survive** every action.
6. **Validate live & inline,** one reason at a time; preserve input + Retry on failure; never a raw error
   string.
7. **Trust + undo:** own-domain edits apply now with **toast-undo**; cross-domain acts are a
   **handshake**; only value/credential acts reach **one Settings review**. Guard hard-deletes.
8. **Built for the 20th action:** full keyboard path, smart zero-typing defaults, **batch** matching.
9. **Legibility of skill & value:** a skill level is **behaviorally anchored + evidence-backed**
   (`Independent · 4 tasks · 2 shipped`) — never an abstract number or an unbacked stamp; it **ranks,
   never gates** (capacity gates). **STR is always shown legibly** where it appears — as *contribution ≈
   N* / *accruing vs settled* with a one-tap "how it's computed" (hours × rate) — and is **absent
   everywhere it isn't the point** (task board, roster, home). Quiet, not hidden; legible, not loud.
10. **Feedback & social state:** every act shows its **consequence inline** and **notifies** the people
    affected; an assignment is a **proposal with state** (proposed → active), so no silent conscription.
11. **One object pattern:** card → drawer (peek) → route (deep); peeking a related entity never loses the
    parent. No drawer-hosting-a-whole-app.
12. **Empty / loading / error are designed states**, and a **notification inbox** is the async spine.

---

## 6. Vocabulary (the only words that exist in the UI)

**Unit · Chapter · Working Group · Person · Project · Need · Task · Owner · Assign · Skill · level
(Learning / Independent / Lead) · evidence · capacity (hours) · Milestone · Finish · Settle · Split ·
contribution · STR · wallet · steward · Review.**

Kept (the value layer, used only on My / Settle / Settings): **STR · contribution · accruing · settled ·
Settle · Split · wallet · pool.**

Banned, everywhere: *slot · open_need · work_labor · seat · bind · forge · seat_direct · nominal/liquid
(say **accruing/settled**) · stake · mint · harvest (say **Settle**) · guild · badge · certify ·
apprentice/journeyman/craftsman/master · Beginner/Intermediate/Advanced/Expert · mining · miner.*

---

## 7. Build order — value first, from zero

This is a rebuild, not a patch; build it in the order it delivers truth:

0. **The living record** — Unit/Person/Project/Task model + the **Projects** surface (task board ·
   coverage · links · body) + **import the WG's existing doc**. *A WG drops its doc on day one.*
1. **My tasks** — the cross-project worklist (the seed of the P2 member view).
2. **People + capacity** — roster, skills (tag + Learning/Independent/Lead), evidence auto-derived from
   the record, time-phased capacity bars.
3. **Form by matching** — Needs + the select→glow→click seam.
4. **Contribution + Settle** — hours feed the STR ledger; **Finish → Split → STR paid** (§4.4); STR shows
   on My / profile (quiet). *The economy, riding on a record that already works.*
5. **Social spine** — assignment-as-proposal + notification inbox.
6. **Settings** — catalogs · economy (rates, settlement review) · the minimal approvals.
7. *(Phase 2)* — flip the spotlight: STR becomes the **member's hero** (my wallet, my contribution,
   member logs in & acts for self). Same ledger, same Settle — new point of view.

The current build's **STR ledger and settlement logic are reused** (they're the goal); what's **left
behind** is everything that buried them — the forge/stake/exam/endorsement machinery, the
slots/needs/commitments tangle, the 20-route admin sprawl, and the **wallet/mining home** that pointed
the economy at the wrong user.

---

## 8. Done means

> A working group **runs on this instead of its Google Doc**; a chapter **staffs a project in minutes**;
> a member opens **My** and sees **every task they own across every project** — and when a project ships,
> it **Settles into STR** that lands on the contributors' wallets. The economy is the **goal**, settled on
> a record that is finally **true** because the community actually keeps it here. STR is loud at Settle
> and on the wallet, **quiet everywhere the daily work happens.**

**The dial, stated plainly:** STR is the spine and is never cut. The only judgment is **how present** it
is in Phase 1 — this PRD keeps it *legible but quiet* (visible on My / profile / Settle; absent on the
task board / roster / home). If you want it more prominent in Phase 1 (e.g. a contribution number on
every person card), that's a one-knob change to §4.5/§5.9 — the structure doesn't move.
