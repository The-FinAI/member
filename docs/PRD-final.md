# The Fin AI Community — The System (clean-slate PRD)

*Designed from our logic alone. **Not** a migration of what exists, **not** a list of deltas, **not** a
de-risked rollout of the current build. This is what the system **is**. Where today's code conflicts with
this, today's code is wrong. The reasoning trail lives in `redesign-hci.md`; this is the destination.*

---

## 0. The one decision everything else follows from

> **The product is a *record*, not an *exchange*.**

A research community's working groups keep their life in a Google Doc; its chapters keep "who can do
what" in their heads. The product replaces **those** — a shared, queryable record of **projects, people,
and work**. That is the whole product.

Two consequences, stated without hedging:

1. **Phase 1 has no economy UI. None.** No wallet hero, no STR balance, no nominal/liquid, no mining, no
   stake, no settlement ceremony, no leaderboard. The officers who use Phase 1 **do not care about STR**
   (we established this from how they actually work), and the real WG record **contains no STR anywhere**.
   Contribution still **accrues silently** in the ledger (every logged hour is recorded); it simply has
   **zero surface** until Phase 2 turns it into a member-facing wallet. Hiding the economy isn't a UX
   trick — in Phase 1 it genuinely **is not part of the product**.
2. **The unit of value is the *record being true and useful*, not a token.** Success = a WG runs on this
   instead of its doc; a chapter staffs a project from it in minutes. Credit is a Phase-2 reward layered
   on a record that already works.

Everything below is the minimal system that delivers that, and nothing more.

---

## 1. The model — six things, and only six

```
Unit ─┬─ Chapter ─── Person ──< holds >── Skill@level (+ provenance)
      │                 │  capacity: hours / month (time-phased)
      │                 └──< member of >── Project   (a Membership: role, hours, since)
      └─ Working Group ─ Project ─┬─ Need   (formation: a skill@level | a resource + capacity)
                                  ├─ Task   (execution: group? · name · type? · owner? · state · note)
                                  └─ Milestone
```

| Thing | One line |
|---|---|
| **Unit** | a **Chapter** (contains people) or a **Working Group** (contains projects). The two domains. |
| **Person** | a researcher (P1: a card a chapter steward manages). Has **skills** (each at a level, with **provenance**) and **capacity** (hours/month, shown per period). |
| **Project** | work toward a publication, owned by one WG. Identity (emoji · code · title) · status · links (Proposal/Arxiv/References) · body · **team** · **tasks** · **milestones**. |
| **Need** | what a project requires to **form**: a skill@level, or a resource, with a capacity & headcount. Filled by **matching** → creates a Membership. |
| **Task** | the **execution** unit: `{group?, name, type?, owner?(TBD=open), state, note}`. Assigned **directly**. |
| **Membership** | a Person on a Project: their role, monthly hours, since-date. The only place hours/contribution live. |

Plus two flat reference lists: **Skill** (name + a one-line rubric) and **Milestone type**. That is the
entire schema. ~6 core tables. If something needs a seventh noun, question it before adding it.

---

## 2. Two logics, one lifecycle

A project moves through two logics, in order — both first-class, never conflated:

```
 Propose ──▶ FORM (resource matching) ──▶ RUN (direct task work) ──▶ Finish ──▶ [Split, silent in P1]
   create        post Needs · match            task board · owners        close       credit accrues,
   the project   people by skill+capacity      assigned directly          the work    revealed in P2
```

- **FORM = matching.** The project declares **Needs**; a chapter steward matches **People** to them by
  skill and **spare capacity**. Output: the **team**. This is the only place skill/level/capacity gating
  exists. A project doesn't run until it's resourced.
- **RUN = the living record.** The team works **Tasks**; the lead assigns **owners directly** (a
  teammate, or TBD), tracks status, keeps coverage checklists, links, prose. **This is the thing that
  replaces the Google Doc** — and it is the product's daily heartbeat.

**Need ≠ Task.** Matching produces the team; tasks organize the team's work. Different objects, different
stages.

---

## 3. Surfaces — four, period

| Surface | Who steers | What it is |
|---|---|---|
| **Projects** | WG steward (everyone browses) | **The living record.** Every project as its doc-section: task board · coverage · links · body · team · status. The main surface. |
| **People** | Chapter steward (everyone browses) | The **roster** (skills + capacity bars) and the **matching** board that fills forming projects' Needs. |
| **My** | everyone | My projects, **my tasks across all of them**, my profile/skills. (P2: + my contribution & wallet — the hero then.) |
| **Settings** | admin | Catalogs (skills + rubrics · project types · milestone types · units & stewards) and the few real approvals. |

**Home is not a surface — it is a router** that drops you into your domain with a **"what needs me"**
list on top: *WG steward* — "X finished · a Need is fillable · 3 tasks unowned"; *Chapter steward* — "2
Needs your people fit · 1 person freed up." A dual-role person sees **two clean surfaces**, never a
blended one. No console. No wallet. No leaderboard. No forge queue.

---

## 4. The flows that define the product

**4.1 Run a project (the heartbeat) — replaces the doc.** Open a project → its **task board**
(`Task · Type · Owner · Status · Note`, inline-editable; add a row; assign an owner or leave TBD; click a
cell to change state) · **coverage** groups (e.g. language × state × owner) · **links** (Proposal · Arxiv
· References) · **body**. Cross-project views the doc can't give: **all open/TBD tasks in the WG** (the
backlog), **my tasks everywhere**, by owner, what changed this week.

**4.2 Form a project — matching.** Create (emoji · code · type · proposal) → post **Needs** (skill@level
or resource + capacity), each showing the **candidate-pool size** so demand isn't blind → on the People
surface, select a person → fitting Needs glow with their **spare capacity** and **why they fit** → click
→ confirm pre-filled to min(free, need) → **Assign**. Select→glow→click is primary; drag optional.

**4.3 Register & steward people.** Add a card: name · email · affiliation · **hours** · skills (each
level carries a **rubric** and a **provenance** — certified-by / self-claimed, visually distinct). Own-
roster edits apply **immediately, with undo**.

**4.4 Finish.** Mark finished; **contribution (logged hours) is sealed**. In P1 that's the end the
officer sees. *(P2: a Split view distributes credit, defaulting weights to logged hours, with a fairness
summary — built when the economy surfaces.)*

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
9. **Skill legibility:** every level shows a **rubric + provenance**. (No economy legibility needed in
   P1 — there is no economy on screen.)
10. **Feedback & social state:** every act shows its **consequence inline** and **notifies** the people
    affected; an assignment is a **proposal with state** (proposed → active), so no silent conscription.
11. **One object pattern:** card → drawer (peek) → route (deep); peeking a related entity never loses the
    parent. No drawer-hosting-a-whole-app.
12. **Empty / loading / error are designed states**, and a **notification inbox** is the async spine.

---

## 6. Vocabulary (the only words that exist in the UI)

**Unit · Chapter · Working Group · Person · Project · Need · Task · Owner · Assign · Skill · level
(Beginner/Intermediate/Advanced/Expert) · capacity (hours) · Milestone · Finish · steward · Review.**

Banned, everywhere: *slot · open_need · work_labor · seat · bind · forge · seat_direct · nominal · liquid
· stake · mint · harvest · settle · guild · apprentice/journeyman/craftsman/master · STR · wallet ·
credit* — none appear in Phase 1.

---

## 7. Build order — value first, from zero

This is a rebuild, not a patch; build it in the order it delivers truth:

0. **The living record** — Unit/Person/Project/Task model + the **Projects** surface (task board ·
   coverage · links · body) + **import the WG's existing doc**. *A WG drops its doc on day one.*
1. **My tasks** — the cross-project worklist (the seed of the P2 member view).
2. **People + capacity** — roster, skills with provenance, time-phased capacity bars.
3. **Form by matching** — Needs + the select→glow→click seam.
4. **Social spine** — assignment-as-proposal + notification inbox.
5. **Settings** — catalogs + the minimal approvals.
6. *(Phase 2)* — the economy reveal: contribution → credit, Split, wallet, the member-as-self mode.

Everything in the current build that isn't on this path — the STR/forge/stake/exam/endorsement
machinery, the slots/needs/commitments tangle, the 20-route admin sprawl, the wallet home — is **not
migrated. It is left behind.**

---

## 8. Done means

> A working group **runs on this instead of its Google Doc**; a chapter **staffs a project in minutes**;
> a member opens **My** and sees **every task they own across every project** — and in all of Phase 1, no
> one ever sees, types, or has to understand a single unit of currency. The economy is real in the
> ledger and **invisible on screen** until the community is ready to make it the point.

**The one call that is yours, not mine:** shipping Phase 1 with **zero economy UI** is a product-strategy
bet (record-first, incentives-later). I've made it the spine because our logic points there unanimously —
but if STR must be visible in Phase 1, say so, and only §0.1 changes; the rest of the system stands.
